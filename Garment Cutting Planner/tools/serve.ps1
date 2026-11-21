# Tiny read-only web server for testing the planner at http://localhost:8765/marker-planner.html
# Serves files from the project folder only (GET), on this computer only.
param([int]$Port = 8765)
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript"; ".json" = "application/json"; ".svg" = "image/svg+xml"; ".png" = "image/png"; ".jpg" = "image/jpeg"; ".md" = "text/plain; charset=utf-8"; ".wasm" = "application/wasm" }
$l = New-Object Net.HttpListener; $l.Prefixes.Add("http://localhost:$Port/"); $l.Start()
Write-Output "serving $root on http://localhost:$Port/"
while ($l.IsListening) {
  $c = $l.GetContext(); $res = $c.Response
  try {
    $rel = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart("/")); if (-not $rel) { $rel = "marker-planner.html" }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ($c.Request.HttpMethod -ne "GET" -or -not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) { $res.StatusCode = 404 }
    else { $b = [IO.File]::ReadAllBytes($full); $ext = [IO.Path]::GetExtension($full).ToLower(); $res.ContentType = $(if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" }); $res.Headers.Add("Cache-Control", "no-store"); $res.OutputStream.Write($b, 0, $b.Length) }
  } catch { $res.StatusCode = 500 } finally { $res.Close() }
}

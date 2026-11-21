# Puts the compiled sparrow WebAssembly module into marker-planner.html (gzip, then base64),
# inside <script type="application/octet-stream" id="sp-wasm">. Run after:
#   $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
#   $env:CARGO_TARGET_DIR = "$env:USERPROFILE\sparrow-build\target"
#   cargo build --release --target wasm32-wasip1        (in tools\sparrow-wasm)
param(
  [string]$Wasm = "$env:USERPROFILE\sparrow-build\target\wasm32-wasip1\release\sparrow_wasm.wasm",
  [string]$Html = (Join-Path $PSScriptRoot "..\..\marker-planner.html")
)
$ErrorActionPreference = "Stop"
$bytes = [IO.File]::ReadAllBytes($Wasm)
$ms = New-Object IO.MemoryStream
$gz = New-Object IO.Compression.GZipStream($ms, [IO.Compression.CompressionLevel]::Optimal)
$gz.Write($bytes, 0, $bytes.Length); $gz.Close()
$b64 = [Convert]::ToBase64String($ms.ToArray())
$sha = (Get-FileHash $Wasm -Algorithm SHA256).Hash.ToLower()
$path = (Resolve-Path $Html).Path   # note: PowerShell names are case-insensitive, so keep the text in $page
$page = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$re = '<script type="application/octet-stream" id="sp-wasm"[^>]*>[\s\S]*?</script>'
if (-not [regex]::IsMatch($page, $re)) { throw "sp-wasm placeholder not found in $path" }
$tag = '<script type="application/octet-stream" id="sp-wasm" data-sha256="' + $sha + '">' + $b64 + '</script>'
$rx = New-Object Text.RegularExpressions.Regex($re)
$page = $rx.Replace($page, [Text.RegularExpressions.MatchEvaluator] { param($m) $tag }, 1)
[IO.File]::WriteAllText($path, $page, (New-Object Text.UTF8Encoding($false)))
"embedded {0:N0} bytes of wasm as {1:N0} characters (sha256 {2})" -f $bytes.Length, $b64.Length, $sha.Substring(0, 12)

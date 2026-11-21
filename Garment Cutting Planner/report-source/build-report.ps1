param(
  [Parameter(Mandatory)] [string]$Source,     # simple markdown-like source (UTF-8)
  [Parameter(Mandatory)] [string]$OutBase,    # output path without extension
  [string]$Lang = "en"                         # en or bn
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$lines = [System.IO.File]::ReadAllLines($Source, [System.Text.Encoding]::UTF8)

# ---------- parse into blocks ----------
$blocks = New-Object System.Collections.ArrayList
$i = 0
while ($i -lt $lines.Count) {
  $l = $lines[$i]
  if ($l.Trim() -eq "") { $i++; continue }
  if ($l -match '^===PAGEBREAK===') { [void]$blocks.Add(@{t='pb'}); $i++; continue }
  if ($l -match '^TITLE: (.*)') { [void]$blocks.Add(@{t='title'; x=$matches[1]}); $i++; continue }
  if ($l -match '^SUBTITLE: (.*)') { [void]$blocks.Add(@{t='subtitle'; x=$matches[1]}); $i++; continue }
  if ($l -match '^(#{1,3}) (.*)') { [void]$blocks.Add(@{t="h$($matches[1].Length)"; x=$matches[2]}); $i++; continue }
  if ($l -match '^> (.*)') {
    $txt = @(); while ($i -lt $lines.Count -and $lines[$i] -match '^> (.*)') { $txt += $matches[1]; $i++ }
    [void]$blocks.Add(@{t='note'; x=$txt}); continue }
  if ($l -match '^- (.*)') {
    $items = @(); while ($i -lt $lines.Count -and $lines[$i] -match '^- (.*)') { $items += $matches[1]; $i++ }
    [void]$blocks.Add(@{t='ul'; x=$items}); continue }
  if ($l -match '^\d+\. (.*)') {
    $items = @(); while ($i -lt $lines.Count -and $lines[$i] -match '^\d+\. (.*)') { $items += $matches[1]; $i++ }
    [void]$blocks.Add(@{t='ol'; x=$items}); continue }
  if ($l -match '^\|') {
    $rows = @()
    while ($i -lt $lines.Count -and $lines[$i] -match '^\|') {
      $r = $lines[$i].Trim()
      if ($r -notmatch '^\|[\s\-\|:]+\|$') {
        $cells = $r.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        $rows += ,@($cells)
      }
      $i++
    }
    [void]$blocks.Add(@{t='table'; x=$rows}); continue }
  [void]$blocks.Add(@{t='p'; x=$l}); $i++
}

# ---------- inline helpers ----------
function Split-Bold([string]$s) {
  # returns list of @(text, isBold)
  $parts = $s -split '\*\*'
  $out = @()
  for ($k = 0; $k -lt $parts.Count; $k++) { if ($parts[$k] -ne '') { $out += ,@($parts[$k], ($k % 2 -eq 1)) } }
  return ,$out
}
function HtmlEsc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }
function XmlEsc([string]$s) { return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }
function Html-Inline([string]$s) {
  $r = ''
  foreach ($p in (Split-Bold $s)) { if ($p[1]) { $r += "<strong>$(HtmlEsc $p[0])</strong>" } else { $r += (HtmlEsc $p[0]) } }
  return $r
}

$isBn = ($Lang -eq 'bn')
$csFont = 'Nirmala UI'
$latin = if ($isBn) { 'Nirmala UI' } else { 'Calibri' }

function Run-Xml([string]$text, [bool]$bold, [string]$color = '', [int]$size = 0) {
  $rpr = ''
  if ($bold) { $rpr += '<w:b/><w:bCs/>' }
  if ($color) { $rpr += "<w:color w:val=`"$color`"/>" }
  if ($size -gt 0) { $rpr += "<w:sz w:val=`"$size`"/><w:szCs w:val=`"$size`"/>" }
  return "<w:r><w:rPr>$rpr</w:rPr><w:t xml:space=`"preserve`">$(XmlEsc $text)</w:t></w:r>"
}
function Runs-Xml([string]$s, [bool]$allBold = $false, [string]$color = '', [int]$size = 0) {
  $r = ''
  foreach ($p in (Split-Bold $s)) { $r += Run-Xml $p[0] ($p[1] -or $allBold) $color $size }
  return $r
}

# ---------- HTML ----------
$css = @"
@page { size: A4; margin: 18mm 17mm 18mm 17mm; }
:root { --ink:#1d2433; --muted:#5b6475; --accent:#0f5e6e; --soft:#e8f1f3; --line:#cfd8dc; --warn:#fff6e0; }
body { font-family: $(if ($isBn) { "'Nirmala UI', 'Noto Sans Bengali', sans-serif" } else { "'Segoe UI', Calibri, Arial, sans-serif" }); color: var(--ink); background:#fff; font-size: $(if ($isBn) { '11pt' } else { '10.5pt' }); line-height: $(if ($isBn) { '1.65' } else { '1.5' }); margin:0; }
h1.title { font-size: 24pt; color: var(--accent); margin: 0 0 4pt 0; line-height:1.25; }
p.subtitle { color: var(--muted); font-size: 12pt; margin: 0 0 14pt 0; border-bottom: 2px solid var(--accent); padding-bottom: 10pt; }
h1 { font-size: 16pt; color: var(--accent); margin: 18pt 0 6pt 0; border-bottom: 1px solid var(--line); padding-bottom: 3pt; page-break-after: avoid; }
h2 { font-size: 13pt; color: var(--ink); margin: 14pt 0 4pt 0; page-break-after: avoid; }
h3 { font-size: 11pt; color: var(--accent); margin: 10pt 0 3pt 0; page-break-after: avoid; }
p { margin: 0 0 7pt 0; }
ul, ol { margin: 0 0 8pt 0; padding-left: 18pt; }
$(if ($isBn) { 'ol { list-style-type: bengali; }' })
li { margin: 0 0 3pt 0; }
table { border-collapse: collapse; width: 100%; margin: 4pt 0 10pt 0; page-break-inside: avoid; font-size: 0.95em; }
th { background: var(--accent); color: #fff; text-align: left; padding: 4pt 6pt; font-weight: 600; }
td { border-bottom: 1px solid var(--line); padding: 4pt 6pt; vertical-align: top; }
tr:nth-child(even) td { background: #f6f9fa; }
div.note { background: var(--soft); border-left: 4px solid var(--accent); padding: 7pt 10pt; margin: 6pt 0 10pt 0; page-break-inside: avoid; }
div.note p { margin: 0 0 3pt 0; }
.pb { page-break-after: always; }
"@
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("<!doctype html><html lang=`"$Lang`"><head><meta charset=`"utf-8`"><title>Report</title><style>$css</style></head><body>")
foreach ($b in $blocks) {
  switch ($b.t) {
    'title'    { [void]$sb.Append("<h1 class=`"title`">$(Html-Inline $b.x)</h1>") }
    'subtitle' { [void]$sb.Append("<p class=`"subtitle`">$(Html-Inline $b.x)</p>") }
    'h1' { [void]$sb.Append("<h1>$(Html-Inline $b.x)</h1>") }
    'h2' { [void]$sb.Append("<h2>$(Html-Inline $b.x)</h2>") }
    'h3' { [void]$sb.Append("<h3>$(Html-Inline $b.x)</h3>") }
    'p'  { [void]$sb.Append("<p>$(Html-Inline $b.x)</p>") }
    'pb' { [void]$sb.Append("<div class=`"pb`"></div>") }
    'note' { [void]$sb.Append("<div class=`"note`">"); foreach ($n in $b.x) { [void]$sb.Append("<p>$(Html-Inline $n)</p>") }; [void]$sb.Append("</div>") }
    'ul' { [void]$sb.Append("<ul>"); foreach ($n in $b.x) { [void]$sb.Append("<li>$(Html-Inline $n)</li>") }; [void]$sb.Append("</ul>") }
    'ol' { [void]$sb.Append("<ol>"); foreach ($n in $b.x) { [void]$sb.Append("<li>$(Html-Inline $n)</li>") }; [void]$sb.Append("</ol>") }
    'table' {
      [void]$sb.Append("<table><thead><tr>")
      foreach ($c in $b.x[0]) { [void]$sb.Append("<th>$(Html-Inline $c)</th>") }
      [void]$sb.Append("</tr></thead><tbody>")
      for ($r = 1; $r -lt $b.x.Count; $r++) {
        [void]$sb.Append("<tr>"); foreach ($c in $b.x[$r]) { [void]$sb.Append("<td>$(Html-Inline $c)</td>") }; [void]$sb.Append("</tr>")
      }
      [void]$sb.Append("</tbody></table>")
    }
  }
}
[void]$sb.Append("</body></html>")
$htmlPath = "$OutBase.html"
[System.IO.File]::WriteAllText($htmlPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# ---------- DOCX ----------
$textWidth = 9638   # A4 11906 - 2*1134
$body = New-Object System.Text.StringBuilder
foreach ($b in $blocks) {
  switch ($b.t) {
    'title'    { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"Title`"/></w:pPr>$(Runs-Xml $b.x)</w:p>") }
    'subtitle' { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"Subtitle`"/></w:pPr>$(Runs-Xml $b.x)</w:p>") }
    'h1' { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"Heading1`"/></w:pPr>$(Runs-Xml $b.x)</w:p>") }
    'h2' { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"Heading2`"/></w:pPr>$(Runs-Xml $b.x)</w:p>") }
    'h3' { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"Heading3`"/></w:pPr>$(Runs-Xml $b.x)</w:p>") }
    'p'  { [void]$body.Append("<w:p>$(Runs-Xml $b.x)</w:p>") }
    'pb' { [void]$body.Append("<w:p><w:r><w:br w:type=`"page`"/></w:r></w:p>") }
    'note' {
      foreach ($n in $b.x) {
        [void]$body.Append("<w:p><w:pPr><w:pBdr><w:left w:val=`"single`" w:sz=`"24`" w:space=`"8`" w:color=`"0F5E6E`"/></w:pBdr><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"E8F1F3`"/><w:spacing w:after=`"60`"/><w:ind w:left=`"227`" w:right=`"113`"/></w:pPr>$(Runs-Xml $n)</w:p>")
      }
      [void]$body.Append("<w:p><w:pPr><w:spacing w:after=`"0`"/></w:pPr></w:p>")
    }
    'ul' { foreach ($n in $b.x) { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"ListParagraph`"/><w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"1`"/></w:numPr></w:pPr>$(Runs-Xml $n)</w:p>") } }
    'ol' {
      # each numbered list restarts: create a new num instance id
      $script:olCount = 1 + [int]$script:olCount
      $nid = 100 + $script:olCount
      foreach ($n in $b.x) { [void]$body.Append("<w:p><w:pPr><w:pStyle w:val=`"ListParagraph`"/><w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"$nid`"/></w:numPr></w:pPr>$(Runs-Xml $n)</w:p>") }
    }
    'table' {
      $cols = $b.x[0].Count
      $cw = [math]::Floor($textWidth / $cols)
      $tw = $cw * $cols
      [void]$body.Append("<w:tbl><w:tblPr><w:tblW w:w=`"$tw`" w:type=`"dxa`"/><w:tblBorders><w:top w:val=`"single`" w:sz=`"4`" w:color=`"CFD8DC`"/><w:bottom w:val=`"single`" w:sz=`"4`" w:color=`"CFD8DC`"/><w:insideH w:val=`"single`" w:sz=`"4`" w:color=`"CFD8DC`"/><w:left w:val=`"nil`"/><w:right w:val=`"nil`"/><w:insideV w:val=`"nil`"/></w:tblBorders><w:tblLayout w:type=`"fixed`"/><w:tblCellMar><w:top w:w=`"60`" w:type=`"dxa`"/><w:left w:w=`"100`" w:type=`"dxa`"/><w:bottom w:w=`"60`" w:type=`"dxa`"/><w:right w:w=`"100`" w:type=`"dxa`"/></w:tblCellMar></w:tblPr><w:tblGrid>")
      for ($c = 0; $c -lt $cols; $c++) { [void]$body.Append("<w:gridCol w:w=`"$cw`"/>") }
      [void]$body.Append("</w:tblGrid>")
      for ($r = 0; $r -lt $b.x.Count; $r++) {
        $hdr = ($r -eq 0)
        [void]$body.Append("<w:tr>")
        if ($hdr) { $body.Length -= 6; [void]$body.Append("<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>") } else { $body.Length -= 6; [void]$body.Append("<w:tr><w:trPr><w:cantSplit/></w:trPr>") }
        for ($c = 0; $c -lt $cols; $c++) {
          $txt = if ($c -lt $b.x[$r].Count) { $b.x[$r][$c] } else { '' }
          $shd = if ($hdr) { '<w:shd w:val="clear" w:color="auto" w:fill="0F5E6E"/>' } elseif ($r % 2 -eq 0) { '<w:shd w:val="clear" w:color="auto" w:fill="F6F9FA"/>' } else { '' }
          $runs = if ($hdr) { Runs-Xml $txt $true 'FFFFFF' } else { Runs-Xml $txt }
          [void]$body.Append("<w:tc><w:tcPr><w:tcW w:w=`"$cw`" w:type=`"dxa`"/>$shd</w:tcPr><w:p><w:pPr><w:spacing w:before=`"0`" w:after=`"0`"/><w:keepNext/></w:pPr>$runs</w:p></w:tc>")
        }
        [void]$body.Append("</w:tr>")
      }
      [void]$body.Append("</w:tbl><w:p><w:pPr><w:spacing w:after=`"60`"/></w:pPr></w:p>")
    }
  }
}

$ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
$documentXml = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:document $ns><w:body>$($body.ToString())<w:sectPr><w:footerReference w:type=`"default`" r:id=`"rIdFooter`"/><w:pgSz w:w=`"11906`" w:h=`"16838`"/><w:pgMar w:top=`"1134`" w:right=`"1134`" w:bottom=`"1134`" w:left=`"1134`" w:header=`"567`" w:footer=`"567`" w:gutter=`"0`"/></w:sectPr></w:body></w:document>"

$lang = if ($isBn) { '<w:lang w:val="en-US" w:bidi="bn-BD"/>' } else { '<w:lang w:val="en-GB"/>' }
$bodySz = if ($isBn) { 22 } else { 21 }
function HStyle($id, $name, $sz, $color, $before, $after, $outline) {
  return "<w:style w:type=`"paragraph`" w:styleId=`"$id`"><w:name w:val=`"$name`"/><w:basedOn w:val=`"Normal`"/><w:next w:val=`"Normal`"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before=`"$before`" w:after=`"$after`"/><w:outlineLvl w:val=`"$outline`"/></w:pPr><w:rPr><w:rFonts w:ascii=`"$latin`" w:hAnsi=`"$latin`" w:cs=`"$csFont`"/><w:b/><w:bCs/><w:color w:val=`"$color`"/><w:sz w:val=`"$sz`"/><w:szCs w:val=`"$sz`"/></w:rPr></w:style>"
}
$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$latin" w:hAnsi="$latin" w:eastAsia="$latin" w:cs="$csFont"/><w:color w:val="1D2433"/><w:sz w:val="$bodySz"/><w:szCs w:val="$bodySz"/>$lang</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="288" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr><w:rPr><w:rFonts w:ascii="$latin" w:hAnsi="$latin" w:cs="$csFont"/><w:b/><w:bCs/><w:color w:val="0F5E6E"/><w:sz w:val="48"/><w:szCs w:val="48"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="12" w:space="6" w:color="0F5E6E"/></w:pBdr><w:spacing w:before="0" w:after="280"/></w:pPr><w:rPr><w:color w:val="5B6475"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:style>
$(HStyle 'Heading1' 'heading 1' 32 '0F5E6E' 360 120 0)
$(HStyle 'Heading2' 'heading 2' 26 '1D2433' 260 80 1)
$(HStyle 'Heading3' 'heading 3' 22 '0F5E6E' 200 60 2)
<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="60"/><w:ind w:left="567" w:hanging="283"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Footer"><w:name w:val="footer"/><w:basedOn w:val="Normal"/><w:pPr><w:jc w:val="center"/></w:pPr><w:rPr><w:color w:val="5B6475"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>
</w:styles>
"@

$numInst = '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
for ($k = 1; $k -le [int]$script:olCount; $k++) { $numInst += "<w:num w:numId=`"$(100+$k)`"><w:abstractNumId w:val=`"1`"/><w:lvlOverride w:ilvl=`"0`"><w:startOverride w:val=`"1`"/></w:lvlOverride></w:num>" }
$numberingXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="283"/></w:pPr><w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr></w:lvl></w:abstractNum>
<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="340"/></w:pPr></w:lvl></w:abstractNum>
$numInst
</w:numbering>
"@
# bullet char in Symbol font is F0B7; use plain bullet with default font instead
$numberingXml = $numberingXml.Replace('<w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>', '')

$footerLabel = if ($isBn) { 'পৃষ্ঠা ' } else { 'Page ' }
$footerXml = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:ftr $ns><w:p><w:pPr><w:pStyle w:val=`"Footer`"/></w:pPr><w:r><w:t xml:space=`"preserve`">$footerLabel</w:t></w:r><w:r><w:fldChar w:fldCharType=`"begin`"/></w:r><w:r><w:instrText xml:space=`"preserve`"> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType=`"separate`"/></w:r><w:r><w:t>1</w:t></w:r><w:r><w:fldChar w:fldCharType=`"end`"/></w:r></w:p></w:ftr>"

$contentTypes = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>
"@
$rels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>
"@
$docRels = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rIdNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>
"@
$titleText = ($blocks | Where-Object { $_.t -eq 'title' } | Select-Object -First 1).x
$core = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>$(XmlEsc $titleText)</dc:title><dcterms:created xsi:type="dcterms:W3CDTF">2026-11-21T00:00:00Z</dcterms:created></cp:coreProperties>
"@

# validate XML parts parse
foreach ($x in @($documentXml, $stylesXml, $numberingXml, $footerXml, $contentTypes, $rels, $docRels, $core)) { [void]([xml]$x.Trim()) }

$docxPath = "$OutBase.docx"
if (Test-Path $docxPath) { Remove-Item $docxPath -Force }
$fs = [System.IO.File]::Open($docxPath, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$parts = [ordered]@{
  '[Content_Types].xml' = $contentTypes; '_rels/.rels' = $rels; 'docProps/core.xml' = $core
  'word/document.xml' = $documentXml; 'word/styles.xml' = $stylesXml; 'word/numbering.xml' = $numberingXml
  'word/footer1.xml' = $footerXml; 'word/_rels/document.xml.rels' = $docRels
}
foreach ($k in $parts.Keys) {
  $e = $zip.CreateEntry($k)
  $w = New-Object System.IO.StreamWriter($e.Open(), $utf8)
  $w.Write($parts[$k].Trim()); $w.Close()
}
$zip.Dispose(); $fs.Close()

# ---------- PDF via Edge ----------
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$pdfPath = "$OutBase.pdf"
if (Test-Path $pdfPath) { Remove-Item $pdfPath -Force }
$uri = ([System.Uri](Resolve-Path $htmlPath).Path).AbsoluteUri
$tmpProfile = Join-Path $env:TEMP ("edgepdf_" + [guid]::NewGuid())
$p = Start-Process -FilePath $edge -ArgumentList @('--headless=new','--disable-gpu','--no-pdf-header-footer','--print-to-pdf-no-header',"--user-data-dir=`"$tmpProfile`"","--print-to-pdf=`"$pdfPath`"",$uri) -PassThru -Wait -WindowStyle Hidden
Start-Sleep -Milliseconds 500
"blocks: $($blocks.Count)"
"html: $htmlPath"
"docx: $docxPath  ($((Get-Item $docxPath).Length) bytes)"
if (Test-Path $pdfPath) { "pdf: $pdfPath  ($((Get-Item $pdfPath).Length) bytes)" } else { "pdf: NOT CREATED" }

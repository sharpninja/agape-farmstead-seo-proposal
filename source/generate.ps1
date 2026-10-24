param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [string]$Theme = "agape-farm",
    [string]$OutDir = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutDir) { $OutDir = Join-Path $root "..\docs" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$themePath = Join-Path $root "themes\$Theme.json"
if (-not (Test-Path $themePath)) { throw "Theme not found: $themePath" }
$theme = Get-Content $themePath -Raw | ConvertFrom-Json
$t = $theme.tokens

$ymlPath = if ([System.IO.Path]::IsPathRooted($InputFile)) { $InputFile } else { Join-Path $root $InputFile }
if (-not (Test-Path $ymlPath)) { throw "Input YAML not found: $ymlPath" }
$ymlText = Get-Content $ymlPath -Raw

function Parse-SimpleYml([string]$text) {
    $lines = $text -split "`n"
    $root = [ordered]@{}
    $stack = New-Object System.Collections.Stack
    $stack.Push(@{Indent=-1; Node=$root})
    function NextNonEmpty([int]$i) {
        for ($j=$i+1; $j -lt $lines.Count; $j++) {
            $l = $lines[$j]
            if ($l -match '^\s*#' -or $l -match '^\s*$') { continue }
            return $l
        }
        return ""
    }
    for ($i=0; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        if ($raw -match '^\s*#' -or $raw -match '^\s*$') { continue }
        if ($raw -match '^(\s*)-\s+(.*)$') {
            $indent = $Matches[1].Length; $content = $Matches[2]
            while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
            $parent = $stack.Peek().Node
            if ($parent -isnot [System.Collections.IList]) { throw "YAML error: $raw" }
            if ($content -match '^(.+?):\s*(.*)$') {
                $obj = [ordered]@{}
                $obj[$Matches[1].Trim()] = $Matches[2].Trim().Trim('"').Trim("'")
                $parent.Add($obj)
                $stack.Push(@{Indent=$indent; Node=$obj})
            } else {
                $parent.Add($content.Trim().Trim('"').Trim("'"))
            }
        } else {
            if ($raw -match '^(\s*)([^:]+):\s*(.*)$') {
                $indent = $Matches[1].Length; $key = $Matches[2].Trim(); $val = $Matches[3].Trim().Trim('"').Trim("'")
                while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
                $parent = $stack.Peek().Node
                if ($parent -is [System.Collections.IList]) {
                    $obj = [ordered]@{}
                    if ($val -ne '') { $obj['value'] = $val }
                    $parent.Add($obj)
                    if ($val -eq '') { $stack.Push(@{Indent=$indent; Node=$obj}) }
                } else {
                    if ($val -eq '') {
                        $nxt = NextNonEmpty $i
                        if ($nxt -match '^\s*-\s+') {
                            $lst = New-Object System.Collections.ArrayList
                            $parent[$key] = $lst
                            $stack.Push(@{Indent=$indent; Node=$lst})
                        } else {
                            $obj = [ordered]@{}
                            $parent[$key] = $obj
                            $stack.Push(@{Indent=$indent; Node=$obj})
                        }
                    } else {
                        $parent[$key] = $val
                    }
                }
            } else { throw "YAML error: $raw" }
        }
    }
    return $root
}

$deck = Parse-SimpleYml $ymlText
$meta = $deck['meta']
if (-not $meta) { $meta = [ordered]@{} }

function Esc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }

function Render-Slide($slide, [int]$idx) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("<section class=`"slide`" id=`"s$idx`">")
    if ($slide['tag']) { [void]$sb.AppendLine("  <span class=`"tag`">$(Esc $slide['tag'])</span>") }
    if ($slide['phase']) { [void]$sb.AppendLine("  <div class=`"phase-num`">$(Esc $slide['phase'])</div>") }
    if ($slide['timeline']) { [void]$sb.AppendLine("  <div class=`"timeline`">$(Esc $slide['timeline'])</div>") }
    if ($slide['title']) {
        $t = $slide['title'].Replace('__ACCENT__','<span class="accent">').Replace('__ACCENT2__','<span class="accent2">')
        $o = ([regex]::Matches($t,'<span')).Count; $c = ([regex]::Matches($t,'</span>')).Count
        if ($o -gt $c) { $t += '</span>' * ($o-$c) }
        $tag = if ($t -match '<br') { 'h1' } else { 'h2' }
        [void]$sb.AppendLine("  <$tag>$t</$tag>")
    }
    if ($slide['subtitle']) { [void]$sb.AppendLine("  <p class=`"sub`">$(Esc $slide['subtitle'])</p>") }
    if ($slide['stats']) {
        [void]$sb.AppendLine("  <div class=`"stat-row`">")
        foreach ($st in $slide['stats']) {
            [void]$sb.AppendLine("    <div class=`"stat`"><div class=`"n`">$(Esc $st['n'])</div><div class=`"l`">$(Esc $st['l'])</div></div>")
        }
        [void]$sb.AppendLine("  </div>")
    }
    if ($slide['cards']) {
        [void]$sb.AppendLine("  <div class=`"two-col`">")
        foreach ($c in $slide['cards']) {
            [void]$sb.AppendLine("    <div class=`"card`">")
            if ($c['pillar']) { [void]$sb.AppendLine("      <div class=`"pillar $(Esc $c['pillar_class'])`">$(Esc $c['pillar'])</div>") }
            if ($c['title']) { [void]$sb.AppendLine("      <h3>$(Esc $c['title'])</h3>") }
            if ($c['text']) { [void]$sb.AppendLine("      <p>$(Esc $c['text'])</p>") }
            [void]$sb.AppendLine("    </div>")
        }
        [void]$sb.AppendLine("  </div>")
    }
    if ($slide['list']) {
        [void]$sb.AppendLine("  <ul>")
        foreach ($item in $slide['list']) { [void]$sb.AppendLine("    <li>$(Esc $item)</li>") }
        [void]$sb.AppendLine("  </ul>")
    }
    if ($slide['note']) { [void]$sb.AppendLine("  <div class=`"note-box`">$(Esc $slide['note'])</div>") }
    if ($slide['ask']) {
        $a = $slide['ask']
        [void]$sb.AppendLine("  <div class=`"ask-box`">")
        if ($a['title']) { [void]$sb.AppendLine("    <div class=`"price`">$(Esc $a['title'])</div>") }
        if ($a['text']) { [void]$sb.AppendLine("    <p style=`"margin-top:10px;color:var(--muted);font-size:15px;line-height:1.5;`">$(Esc $a['text'])</p>") }
        if ($a['button']) {
            $href = if ($a['button_href']) { $a['button_href'] } else { '#' }
            [void]$sb.AppendLine("    <a class=`"btn`" href=`"$(Esc $href)`">$(Esc $a['button'])</a>")
        }
        [void]$sb.AppendLine("  </div>")
    }
    if ($slide['footer']) { [void]$sb.AppendLine("  <p class=`"footer-note`">$(Esc $slide['footer'])</p>") }
    [void]$sb.AppendLine("</section>")
    return $sb.ToString()
}

$slidesHtml = ""
$idx = 1
foreach ($s in $deck['slides']) { $slidesHtml += (Render-Slide $s $idx) + "`n`n"; $idx++ }

$tpl = Get-Content (Join-Path $root "template.html") -Raw
$reps = [ordered]@{
    '__TITLE__' = $(if ($meta['title']){$meta['title']}else{'Deck'})
    '__DESCRIPTION__' = $(if ($meta['description']){$meta['description']}else{''})
    '__OG_TITLE__' = $(if ($meta['og_title']){$meta['og_title']}else{$(if($meta['title']){$meta['title']}else{'Deck'})})
    '__OG_DESCRIPTION__' = $(if ($meta['og_description']){$meta['og_description']}else{$(if($meta['description']){$meta['description']}else{''})})
    '__THEME_COLOR__' = $t.theme_color
    '__FOREST__' = $t.forest
    '__FOREST_MID__' = $t.forest_mid
    '__ACCENT_COLOR__' = $t.accent
    '__ACCENT_DIM__' = $t.accent_dim
    '__CREAM__' = $t.cream
    '__MUTED__' = $t.muted
    '__CARD_BG__' = $t.card_bg
    '__ACCENT2_COLOR__' = $t.accent2
    '__HEADING_FONT__' = $t.heading_font
    '__BODY_FONT__' = $t.body_font
    '__RADIUS_PX__' = $t.radius_px
    '__PAD_X_PX__' = $t.pad_x_px
    '__PAD_Y_PX__' = $t.pad_y_px
    '__SLIDES__' = $slidesHtml.TrimEnd()
}
foreach ($k in $reps.Keys) { $tpl = $tpl.Replace($k, [string]$reps[$k]) }

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($ymlPath)
$outFile = Join-Path $OutDir "$baseName.html"
Set-Content -Path $outFile -Value $tpl -Encoding UTF8
Write-Host "Generated $outFile ($((Get-Item $outFile).Length) bytes, $($deck['slides'].Count) slides) with theme $Theme"

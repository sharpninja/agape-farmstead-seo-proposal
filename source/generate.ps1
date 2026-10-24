#Requires -Version 5.1
<#
.SYNOPSIS
    Generates a vertical 9:16 HTML slide deck from a YAML content file.
.DESCRIPTION
    Reads deck.yml, merges content into template.html, writes index.html.
    Usage:  .\generate.ps1 [-InputFile deck.yml] [-Template template.html] [-Output index.html]
.PARAMETER InputFile
    Path to the YAML deck definition. Default: deck.yml
.PARAMETER Template
    Path to the HTML template. Default: template.html
.PARAMETER Output
    Path for the generated HTML. Default: index.html
.EXAMPLE
    .\generate.ps1
    .\generate.ps1 -InputFile thanksgiving.yml -Output ../docs/thanksgiving.html
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [string]$InputFile = "deck.yml",
    [string]$Template  = "template.html",
    [string]$Output    = "index.html"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- minimal YAML subset parser ----------
function ConvertFrom-SimpleYAML {
    param([string]$Text)
    $lines = $Text -split "`n"
    $root = [ordered]@{}
    $stack = [System.Collections.Stack]::new()
    $stack.Push(@{ Node = $root; Indent = -1 })

    foreach ($raw in $lines) {
        if ($raw -match '^\s*#' -or $raw -match '^\s*$') { continue }
        if ($raw -match '^(\s*)-\s+(.*)$') {
            $indent = $Matches[1].Length
            $content = $Matches[2]
            while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
            $parent = $stack.Peek().Node
            if (-not ($parent -is [System.Collections.IList])) {
                throw "YAML parse error near: $raw"
            }
            if ($content -match '^(.+?):\s*(.*)$') {
                $obj = [ordered]@{}
                $obj[$Matches[1].Trim()] = $Matches[2].Trim().Trim('"').Trim("'")
                $parent.Add($obj)
                $stack.Push(@{ Node = $obj; Indent = $indent })
            } else {
                $parent.Add($content.Trim().Trim('"').Trim("'"))
            }
        }
        else {
            if ($raw -notmatch '^(\s*)([^:]+):\s*(.*)$') {
                throw "YAML parse error near: $raw"
            }
            $indent = $Matches[1].Length
            $key = $Matches[2].Trim()
            $val = $Matches[3].Trim().Trim('"').Trim("'")
            while ($stack.Peek().Indent -ge $indent) { [void]$stack.Pop() }
            $parent = $stack.Peek().Node
            if ($parent -is [System.Collections.IList]) {
                $obj = [ordered]@{}
                if ($val -ne '') { $obj['value'] = $val }
                $parent.Add($obj)
                if ($val -eq '') { $stack.Push(@{ Node = $obj; Indent = $indent }) }
            } else {
                if ($val -eq '') {
                    $obj = [ordered]@{}
                    $parent[$key] = $obj
                    $stack.Push(@{ Node = $obj; Indent = $indent })
                } else {
                    $parent[$key] = $val
                }
            }
        }
    }
    return $root
}

# ---------- slide renderers ----------
function Render-Slide {
    param($Slide, [int]$Index)
    $id = "s$Index"
    $parts = @()
    $parts += "<section class=`"slide`" id=`"$id`">"

    if ($Slide.tag)    { $parts += "  <span class=`"tag`">$($Slide.tag)</span>" }
    if ($Slide.phase)  { $parts += "  <div class=`"phase-num`">$($Slide.phase)</div>" }
    if ($Slide.timeline) { $parts += "  <div class=`"timeline`">$($Slide.timeline)</div>" }

    if ($Slide.title) {
        $t = $Slide.title -replace '__ACCENT__','<span class="accent">' -replace '__ACCENT2__','<span class="accent2">'
        $open = ([regex]::Matches($t, '<span')).Count
        $close = ([regex]::Matches($t, '</span>')).Count
        for ($i = 0; $i -lt ($open - $close); $i++) { $t += '</span>' }
        if ($t -match '<br') { $parts += "  <h1>$t</h1>" } else { $parts += "  <h2>$t</h2>" }
    }

    if ($Slide.subtitle) { $parts += "  <p class=`"sub`">$($Slide.subtitle)</p>" }

    if ($Slide.stats) {
        $parts += '  <div class="stat-row">'
        foreach ($st in $Slide.stats) {
            $parts += "    <div class=`"stat`"><div class=`"n`">$($st.n)</div><div class=`"l`">$($st.l)</div></div>"
        }
        $parts += '  </div>'
    }

    if ($Slide.cards) {
        $parts += '  <div class="two-col">'
        foreach ($c in $Slide.cards) {
            $parts += '    <div class="card">'
            if ($c.pillar) { $parts += "      <div class=`"pillar $($c.pillar_class)`">$($c.pillar)</div>" }
            if ($c.title)  { $parts += "      <h3>$($c.title)</h3>" }
            if ($c.text)   { $parts += "      <p>$($c.text)</p>" }
            $parts += '    </div>'
        }
        $parts += '  </div>'
    }

    if ($Slide.list) {
        $parts += '  <ul>'
        foreach ($item in $Slide.list) { $parts += "    <li>$item</li>" }
        $parts += '  </ul>'
    }

    if ($Slide.note) {
        $parts += "  <div class=`"note-box`">$($Slide.note)</div>"
    }

    if ($Slide.ask) {
        $a = $Slide.ask
        $parts += '  <div class="ask-box">'
        if ($a.title) { $parts += "    <div class=`"price`">$($a.title)</div>" }
        if ($a.text)  { $parts += "    <p style=`"margin-top:10px;color:var(--muted);font-size:15px;line-height:1.5;`">$($a.text)</p>" }
        if ($a.button) {
            $href = if ($a.button_href) { $a.button_href } else { '#' }
            $parts += "    <a class=`"btn`" href=`"$href`">$($a.button)</a>"
        }
        $parts += '  </div>'
    }

    if ($Slide.footer) {
        $parts += "  <p class=`"footer-note`">$($Slide.footer)</p>"
    }

    $parts += '</section>'
    return ($parts -join "`n")
}

# ---------- main ----------
if (-not (Test-Path $InputFile)) { throw "Input file not found: $InputFile" }
if (-not (Test-Path $Template))  { throw "Template not found: $Template" }

$yamlText = Get-Content -Raw -Path $InputFile
$deck = ConvertFrom-SimpleYAML -Text $yamlText

$tpl = Get-Content -Raw -Path $Template

$meta = $deck.meta
if (-not $meta) { $meta = [ordered]@{} }

function Get-Val($obj, $key, $default = '') {
    if ($null -eq $obj) { return $default }
    if ($obj.Contains($key)) { return [string]$obj[$key] }
    return $default
}

$replacements = [ordered]@{
    '__TITLE__'         = (Get-Val $meta 'title' 'Deck')
    '__DESCRIPTION__'   = (Get-Val $meta 'description')
    '__OG_TITLE__'      = (Get-Val $meta 'og_title' (Get-Val $meta 'title'))
    '__OG_DESCRIPTION__'= (Get-Val $meta 'og_description' (Get-Val $meta 'description'))
    '__THEME_COLOR__'   = (Get-Val $meta 'theme_color' '#0d1f17')
    '__FOREST__'        = (Get-Val $meta 'forest' '#0d1f17')
    '__FOREST_MID__'    = (Get-Val $meta 'forest_mid' '#143528')
    '__ACCENT_COLOR__'  = (Get-Val $meta 'accent' '#3fb950')
    '__ACCENT_DIM__'    = (Get-Val $meta 'accent_dim' '#2a7d3a')
    '__CREAM__'         = (Get-Val $meta 'cream' '#f0f6fc')
    '__MUTED__'         = (Get-Val $meta 'muted' '#8ba3b0')
    '__CARD_BG__'       = (Get-Val $meta 'card_bg' '#12261c')
    '__ACCENT2_COLOR__' = (Get-Val $meta 'accent2' '#3fb950')
}

$slidesHtml = ''
$i = 1
if ($deck.slides) {
    foreach ($s in $deck.slides) {
        $slidesHtml += (Render-Slide -Slide $s -Index $i) + "`n`n"
        $i++
    }
}
$replacements['__SLIDES__'] = $slidesHtml.TrimEnd()

foreach ($k in $replacements.Keys) {
    $tpl = $tpl.Replace($k, [string]$replacements[$k])
}

$outDir = Split-Path -Parent $Output
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Set-Content -Path $Output -Value $tpl -Encoding UTF8
Write-Host "Generated $Output ($((Get-Item $Output).Length) bytes, $($i-1) slides)" -ForegroundColor Green

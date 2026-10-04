<#
.SYNOPSIS
    Draws the AI graph backgrounds (ghost/master/ai0.png and ai0_dark.png, 288 x 288)
    in the style of docs/design-system.md.
.DESCRIPTION
    SSP draws the radar chart (getaistate) over the whole 288 x 288 image, so the
    middle is left plain. The image is a sheet of the invitation: a vellum ground
    shaded from top to bottom, the double frame (2px clay outside, 1px gold hairline
    6px inside), gold lozenges on the four corners of the hairline, and Claudia
    (surface26, the smug face) standing faintly in the bottom right corner, clipped
    by the hairline.
    The dark one is the soiree: night ground, night gold hairline and lozenges.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File work/aigraph/make-aigraph.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir = '',
    [string]$Portrait = 'surface26.png'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = (Resolve-Path (Join-Path $here '..\..')).Path
if (-not $OutDir) { $OutDir = Join-Path $root 'ghost\master' }
Add-Type -AssemblyName System.Drawing

# --- palette (docs/design-system.md) --------------------------------------
function C($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

$Size = 288
$src = [System.Drawing.Image]::FromFile((Join-Path $root "work\surfaces\$Portrait"))

function Draw-Sheet([string]$Path, [bool]$Dark) {
    if ($Dark) {
        $top = C 46 26 34; $bottom = C 31 18 24
        $frame = C 74 46 54; $gold = C 201 161 94 204
        $portraitAlpha = 0.10
    } else {
        $top = C 250 245 234; $bottom = C 240 228 206
        $frame = C 180 83 47; $gold = C 185 141 74 204
        $portraitAlpha = 0.12
    }

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # ground: paper shading from top to bottom
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $top, $bottom, 90.0
    $g.FillRectangle($brush, $rect)
    $brush.Dispose()

    # hairline square: 2px frame + 6px gap -> the hairline runs on x = 8.5
    $in = 8.5
    $inSize = $Size - 2 * $in

    # Claudia, faint, standing in the bottom right corner, clipped by the hairline
    $h = 250.0
    $w = $h * $src.Width / $src.Height
    $dx = $Size - $w * 0.62
    $dy = $Size - $h + 18
    $clip = New-Object System.Drawing.RectangleF $in, $in, $inSize, $inSize
    $g.SetClip($clip)
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix33 = $portraitAlpha
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetColorMatrix($cm)
    $dst = New-Object System.Drawing.Rectangle ([int]$dx), ([int]$dy), ([int]$w), ([int]$h)
    $g.DrawImage($src, $dst, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.ResetClip()
    $ia.Dispose()

    # outer frame 2px
    $pen = New-Object System.Drawing.Pen $frame, 2
    $g.DrawRectangle($pen, 1, 1, $Size - 2, $Size - 2)
    $pen.Dispose()

    # gold hairline 1px, crisp
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::None
    $pen = New-Object System.Drawing.Pen $gold, 1
    $g.DrawRectangle($pen, 8, 8, $Size - 17, $Size - 17)
    $pen.Dispose()

    # lozenges (5 x 5) on the corners of the hairline
    $sb = New-Object System.Drawing.SolidBrush (C $gold.R $gold.G $gold.B)
    foreach ($p in @(@(8, 8), @(($Size - 9), 8), @(8, ($Size - 9)), @(($Size - 9), ($Size - 9)))) {
        $x = $p[0]; $y = $p[1]
        $g.FillRectangle($sb, $x, $y - 2, 1, 5)
        $g.FillRectangle($sb, $x - 1, $y - 1, 3, 3)
        $g.FillRectangle($sb, $x - 2, $y, 5, 1)
    }
    $sb.Dispose()

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "wrote $Path"
}

Draw-Sheet (Join-Path $OutDir 'ai0.png') $false
Draw-Sheet (Join-Path $OutDir 'ai0_dark.png') $true
$src.Dispose()

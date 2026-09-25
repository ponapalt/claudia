<#
.SYNOPSIS
    Renders a check sheet of the generated balloons with sample text, to look at.
#>
[CmdletBinding()]
param(
    [string]$Dir,
    [string]$Out,
    [switch]$Vertical
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sampleS = @(
    'あら、あなた。ごきげんよう。',
    'わたくしが直々に見て差し上げますわ。',
    'ふん、悪くない設計ですわね。'
)
$sampleK = @(
    'お嬢様、紅茶が入りましてございます。',
    'それでございます。'
)

$fontName = 'BIZ UD明朝 Medium'
# font.height は descript.txt に合わせる
$fontHeight = 13.0
$d = Join-Path $Dir 'descript.txt'
if (Test-Path $d) {
    foreach ($l in (Get-Content $d -Encoding UTF8)) {
        if ($l -match '^\s*font\.height,\s*(\d+)\s*$') { $fontHeight = [double]$Matches[1] }
    }
}
$inkS = [System.Drawing.Color]::FromArgb(255, 58, 36, 25)
$inkK = [System.Drawing.Color]::FromArgb(255, 34, 38, 58)
$shadowS = [System.Drawing.Color]::FromArgb(255, 240, 228, 206)
$shadowK = [System.Drawing.Color]::FromArgb(255, 214, 223, 243)

$names = if ($Vertical) { @('balloons0', 'balloons2', 'balloonk0', 'balloonk2') }
         else { @('balloons0', 'balloons1', 'balloons2', 'balloonk0', 'balloonk1', 'balloonk2') }

$imgs = @()
foreach ($n in $names) { $imgs += [System.Drawing.Image]::FromFile((Join-Path $Dir "$n.png")) }

$pad = 16
$W = ($imgs | ForEach-Object { $_.Width } | Measure-Object -Maximum).Maximum + $pad * 2
$H = $pad
foreach ($i in $imgs) { $H += $i.Height + $pad }

$bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = 'AntiAliasGridFit'
# desktop-ish background so the transparency shows honestly
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), [System.Drawing.Color]::FromArgb(255, 58, 76, 96), [System.Drawing.Color]::FromArgb(255, 120, 132, 118), 60.0)
$g.FillRectangle($bg, 0, 0, $W, $H)

$font = New-Object System.Drawing.Font($fontName, $fontHeight, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$y = $pad
for ($n = 0; $n -lt $imgs.Count; $n++) {
    $img = $imgs[$n]
    $g.DrawImage($img, $pad, $y, $img.Width, $img.Height)
    $isKero = $names[$n] -match 'k'
    $lines = if ($isKero) { $sampleK } else { $sampleS }
    $ink = if ($isKero) { $inkK } else { $inkS }
    $sh = if ($isKero) { $shadowK } else { $shadowS }
    $bx = if ($Vertical) { $pad + 14 } else { $pad + 23 }
    $ty = $y + 14
    foreach ($l in $lines) {
        $g.DrawString($l, $font, (New-Object System.Drawing.SolidBrush($sh)), ($bx + 1), ($ty + 1))
        $g.DrawString($l, $font, (New-Object System.Drawing.SolidBrush($ink)), $bx, $ty)
        $ty += [int]($fontHeight * 1.38)
    }
    $y += $img.Height + $pad
}
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
foreach ($i in $imgs) { $i.Dispose() }
Write-Host "wrote: $Out"

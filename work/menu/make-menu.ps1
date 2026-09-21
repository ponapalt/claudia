# Generates the owner-draw menu images from work/icon.png.
# Writes ghost/master/menu/menu_background.png, menu_foreground.png and menu_sidebar.png.
# Palette follows the claudia balloon (work/balloon/make-balloon.ps1): ivory parchment,
# terracotta frame, gold rule.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/menu/make-menu.ps1

param(
    [string]$IconPath = (Join-Path $PSScriptRoot '..\icon.png'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\ghost\master\menu')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function RGB($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

$ivory = RGB 255 251 243
$cream = RGB 246 231 210
$select = RGB 240 214 160
$terracotta = RGB 160 74 38
$gold = RGB 197 150 78

# Background and foreground are aligned leftbottom. Beyond the image, SSP extends the
# edge colors, so the right and top edges are kept flat.
$bgW = 360
$bgH = 640
$markSize = 200
$markAlpha = 0.16

$iconImg = [System.Drawing.Image]::FromFile((Resolve-Path $IconPath))

function New-Canvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.SmoothingMode = 'AntiAlias'
    $g.CompositingQuality = 'HighQuality'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    return @($bmp, $g)
}

function Draw-Icon($g, $x, $y, $size, $alpha) {
    $m = New-Object System.Drawing.Imaging.ColorMatrix
    $m.Matrix33 = [single]$alpha
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetColorMatrix($m)
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $rect = New-Object System.Drawing.Rectangle $x, $y, $size, $size
    $g.DrawImage($iconImg, $rect, 0, 0, $iconImg.Width, $iconImg.Height, 'Pixel', $attr)
    $attr.Dispose()
}

function New-Ground($fill) {
    $c = New-Canvas $bgW $bgH
    $bmp = $c[0]; $g = $c[1]
    $g.Clear($fill)
    # the icon is cut off at its left and bottom edges; put those edges on the menu's corner,
    # so she peeks in from the left
    Draw-Icon $g 0 ($bgH - $markSize) $markSize $markAlpha
    $g.Dispose()
    return $bmp
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

$bg = New-Ground $ivory
$bg.Save((Join-Path $OutDir 'menu_background.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose()

$fg = New-Ground $select
$fg.Save((Join-Path $OutDir 'menu_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fg.Dispose()

# Sidebar: terracotta bar aligned to the bottom, the icon in a gold ring at the foot and
# the name written upward above it. The top rows are flat so the bar extends cleanly.
$sbW = 30
$sbH = 640
$c = New-Canvas $sbW $sbH
$sb = $c[0]; $g = $c[1]
$g.Clear($terracotta)

$pen = New-Object System.Drawing.Pen $gold, 1
$g.DrawLine($pen, $sbW - 3.5, 0, $sbW - 3.5, $sbH)
$pen.Dispose()

$ring = 24
$rx = [int](($sbW - 3 - $ring) / 2)
$ry = $sbH - $ring - 5
$clip = New-Object System.Drawing.Drawing2D.GraphicsPath
$clip.AddEllipse($rx, $ry, $ring, $ring)
$brush = New-Object System.Drawing.SolidBrush $ivory
$g.FillPath($brush, $clip)
$brush.Dispose()
$g.SetClip($clip)
Draw-Icon $g ($rx - 2) ($ry - 1) ($ring + 4) 1.0
$g.ResetClip()
$pen = New-Object System.Drawing.Pen $gold, 1.5
$g.DrawEllipse($pen, $rx, $ry, $ring, $ring)
$pen.Dispose()

$font = New-Object System.Drawing.Font 'Palatino Linotype', 13, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
$text = 'Claudia'
$size = $g.MeasureString($text, $font)
$state = $g.Save()
$g.TranslateTransform([single](($sbW - 3) / 2), [single]($ry - 8))
$g.RotateTransform(-90)
$brush = New-Object System.Drawing.SolidBrush (RGB 238 214 170)
$g.DrawString($text, $font, $brush, [single]0, [single](-$size.Height / 2))
$brush.Dispose()
$gem = New-Object System.Drawing.SolidBrush $gold
$dx = $size.Width + 6
$g.FillPolygon($gem, [System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ($dx), 0),
    (New-Object System.Drawing.PointF ($dx + 3), -3),
    (New-Object System.Drawing.PointF ($dx + 6), 0),
    (New-Object System.Drawing.PointF ($dx + 3), 3)))
$gem.Dispose()
$g.Restore($state)
$font.Dispose()
$g.Dispose()
$sb.Save((Join-Path $OutDir 'menu_sidebar.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sb.Dispose()

$iconImg.Dispose()
Get-ChildItem -LiteralPath $OutDir -Filter 'menu_*.png' | ForEach-Object { '{0}  {1} bytes' -f $_.Name, $_.Length }

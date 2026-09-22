# Generates the owner-draw menu images for Claudia (\0) and Anthony (\1).
# Writes into ghost/master/menu/:
#   menu_background.png, menu_foreground.png, menu_sidebar.png                 (Claudia)
#   menu_anthony_background.png, menu_anthony_foreground.png, menu_anthony_sidebar.png
# The ghost returns one set or the other from yaya_string.dic (On_menu.*), depending on
# which character was clicked last. The alignment stays in ghost/master/descript.txt.
#
# Claudia's palette follows the claudia balloon (work/balloon/make-balloon.ps1): ivory
# parchment, terracotta frame, gold rule. Anthony's uses his tailcoat navy and pale blue.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/menu/make-menu.ps1

param(
    [string]$WorkDir = (Join-Path $PSScriptRoot '..'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\ghost\master\menu')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function RGB($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

# Background and foreground are aligned leftbottom. Beyond the image, SSP extends the
# edge colors, so the right and top edges are kept flat.
$bgW = 360
$bgH = 640
$figH = 300
$figMargin = 6
$figAlpha = 0.16

$sbW = 30
$sbH = 640

$characters = @(
    @{
        Prefix = 'menu_'
        Name = 'Claudia'
        Icon = 'icon_c.png'
        Full = 'icon_c_full.png'
        # opaque bounds of the full-body image (x, y, w, h)
        FullRect = @(124, 56, 777, 1425)
        Ground = (RGB 255 251 243)
        Select = (RGB 240 214 160)
        Bar = (RGB 160 74 38)
        Gold = (RGB 197 150 78)
        Label = (RGB 238 214 170)
    },
    @{
        Prefix = 'menu_anthony_'
        Name = 'Anthony'
        Icon = 'icon_a.png'
        Full = 'icon_a_full.png'
        FullRect = @(76, 120, 873, 1317)
        Ground = (RGB 244 247 255)
        Select = (RGB 208 220 248)
        Bar = (RGB 49 49 62)
        Gold = (RGB 197 150 78)
        Label = (RGB 214 222 246)
    }
)

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

# The sources keep the glow color under alpha 0. Premultiply them first so the color
# does not bleed into the edges when they are scaled down.
function Open-Image($path) {
    $src = [System.Drawing.Image]::FromFile((Resolve-Path $path))
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $g.Dispose()
    $src.Dispose()
    return $bmp
}

function Draw-Image($g, $img, $dx, $dy, $dw, $dh, $sx, $sy, $sw, $sh, $alpha) {
    $m = New-Object System.Drawing.Imaging.ColorMatrix
    $m.Matrix33 = [single]$alpha
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetColorMatrix($m)
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $rect = New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh
    $g.DrawImage($img, $rect, $sx, $sy, $sw, $sh, 'Pixel', $attr)
    $attr.Dispose()
}

# Background or foreground: flat ground with the full-body figure standing faintly in
# the bottom-left corner, which is always visible with leftbottom alignment.
function New-Ground($ch, $full, $fill) {
    $c = New-Canvas $bgW $bgH
    $bmp = $c[0]; $g = $c[1]
    $g.Clear($fill)
    $r = $ch.FullRect
    $w = [int]($r[2] * $figH / $r[3])
    Draw-Image $g $full $figMargin ($bgH - $figH - $figMargin) $w $figH $r[0] $r[1] $r[2] $r[3] $figAlpha
    $g.Dispose()
    return $bmp
}

# Sidebar: a bar aligned to the bottom, the face icon in a gold ring at the foot and the
# name written upward above it. The top rows are flat so the bar extends cleanly.
function New-Sidebar($ch, $icon) {
    $c = New-Canvas $sbW $sbH
    $sb = $c[0]; $g = $c[1]
    $g.Clear($ch.Bar)

    $pen = New-Object System.Drawing.Pen $ch.Gold, 1
    $g.DrawLine($pen, $sbW - 3.5, 0, $sbW - 3.5, $sbH)
    $pen.Dispose()

    $ring = 24
    $rx = [int](($sbW - 3 - $ring) / 2)
    $ry = $sbH - $ring - 5
    $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse($rx, $ry, $ring, $ring)
    $brush = New-Object System.Drawing.SolidBrush $ch.Ground
    $g.FillPath($brush, $clip)
    $brush.Dispose()
    $g.SetClip($clip)
    Draw-Image $g $icon ($rx - 2) ($ry - 1) ($ring + 4) ($ring + 4) 0 0 $icon.Width $icon.Height 1.0
    $g.ResetClip()
    $pen = New-Object System.Drawing.Pen $ch.Gold, 1.5
    $g.DrawEllipse($pen, $rx, $ry, $ring, $ring)
    $pen.Dispose()

    $font = New-Object System.Drawing.Font 'Palatino Linotype', 13, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
    $size = $g.MeasureString($ch.Name, $font)
    $state = $g.Save()
    $g.TranslateTransform([single](($sbW - 3) / 2), [single]($ry - 8))
    $g.RotateTransform(-90)
    $brush = New-Object System.Drawing.SolidBrush $ch.Label
    $g.DrawString($ch.Name, $font, $brush, [single]0, [single](-$size.Height / 2))
    $brush.Dispose()
    $gem = New-Object System.Drawing.SolidBrush $ch.Gold
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
    return $sb
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$png = [System.Drawing.Imaging.ImageFormat]::Png

foreach ($ch in $characters) {
    $icon = Open-Image (Join-Path $WorkDir $ch.Icon)
    $full = Open-Image (Join-Path $WorkDir $ch.Full)

    $bmp = New-Ground $ch $full $ch.Ground
    $bmp.Save((Join-Path $OutDir ($ch.Prefix + 'background.png')), $png)
    $bmp.Dispose()

    $bmp = New-Ground $ch $full $ch.Select
    $bmp.Save((Join-Path $OutDir ($ch.Prefix + 'foreground.png')), $png)
    $bmp.Dispose()

    $bmp = New-Sidebar $ch $icon
    $bmp.Save((Join-Path $OutDir ($ch.Prefix + 'sidebar.png')), $png)
    $bmp.Dispose()

    $icon.Dispose()
    $full.Dispose()
}

Get-ChildItem -LiteralPath $OutDir -Filter 'menu_*.png' | ForEach-Object { '{0}  {1} bytes' -f $_.Name, $_.Length }

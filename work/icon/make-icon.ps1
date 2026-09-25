# Builds the Windows .ico files of the ghost:
#   ghost/master/icon.ico          (Claudia, from work/icon_c_full.png)
#   ghost/master/icon_anthony.ico  (Anthony, from work/icon_a_full.png)
# 16, 24, 32 and 48 px are 32-bit BMP entries, 256 px is a PNG entry.
# The ghost switches the tray icon to Anthony's with \![set,tasktrayicon] while a Claude
# Code session is waiting for an answer (yaya_claudecode.dic).
#
# Design (docs/design-system.md): at every size the whole head, cut square out of the
# full-body image so that the tiara and the rose, or the fin and the bow tie, stay
# inside, sits in a round medallion on its own ground. The ring is gold for Claudia and
# silver for Anthony, 1/20 of the size (at least 1 px), with a thin dark edge so it holds
# on light and dark taskbars alike.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/icon/make-icon.ps1
#   ... make-icon.ps1 -Character anthony      (one of them only)

param(
    [ValidateSet('both', 'claudia', 'anthony')]
    [string]$Character = 'both',
    [string]$OutDir = (Join-Path $PSScriptRoot '..\..\ghost\master')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$sizes = @(16, 24, 32, 48, 256)

function RGB($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

$characters = @{
    claudia = @{
        Full = 'icon_c_full.png'; Out = 'icon.ico'
        # square cut out of the full-body image for the medallion: center x, center y, side
        Crop = @(510, 390, 690)
        Ground = (RGB 250 245 234); Ring = (RGB 185 141 74); Edge = (RGB 140 59 31)
    }
    anthony = @{
        Full = 'icon_a_full.png'; Out = 'icon_anthony.ico'
        Crop = @(510, 485, 790)
        Ground = (RGB 238 242 250); Ring = (RGB 169 177 196); Edge = (RGB 38 42 59)
    }
}

# Premultiply first so the color kept under alpha 0 does not bleed into the edges.
function Open-Source($name) {
    $raw = [System.Drawing.Image]::FromFile((Resolve-Path (Join-Path $PSScriptRoot "..\$name")))
    $src = New-Object System.Drawing.Bitmap $raw.Width, $raw.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $g = [System.Drawing.Graphics]::FromImage($src)
    $g.DrawImage($raw, 0, 0, $raw.Width, $raw.Height)
    $g.Dispose()
    $raw.Dispose()
    return $src
}

function New-Canvas($size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}

# draws the square $crop (center x, center y, side) of $src onto (0, 0, w, w)
function Draw-Face($g, $src, [float]$w, $crop) {
    $sw = $crop[2]; $sx = $crop[0] - $sw / 2; $sy = $crop[1] - $sw / 2
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $rect = New-Object System.Drawing.Rectangle 0, 0, ([int]$w), ([int]$w)
    $g.DrawImage($src, $rect, [float]$sx, [float]$sy, [float]$sw, [float]$sw, 'Pixel', $attr)
    $attr.Dispose()
}

# Draws at four times the size and scales down, then returns a 32bppArgb bitmap.
function Get-Icon($size, $ch, $full) {
    $k = 4
    $S = $size * $k
    $c = New-Canvas $S
    $big = $c[0]; $g = $c[1]
    $ring = [Math]::Max(1.0, $size / 20.0) * $k
    $edge = [Math]::Max(0.5, $size / 96.0) * $k
    $outer = $S - $edge
    $disc = New-Object System.Drawing.Drawing2D.GraphicsPath
    $disc.AddEllipse([float]($edge / 2), [float]($edge / 2), [float]$outer, [float]$outer)
    $b = New-Object System.Drawing.SolidBrush $ch.Ground
    $g.FillPath($b, $disc)
    $b.Dispose()
    $g.SetClip($disc)
    Draw-Face $g $full $S $ch.Crop
    $g.ResetClip()
    # the ring, on the band just inside the edge line
    $ri = $edge + $ring / 2
    $pen = New-Object System.Drawing.Pen $ch.Ring, ([float]$ring)
    $g.DrawEllipse($pen, [float]$ri, [float]$ri, [float]($S - 2 * $ri), [float]($S - 2 * $ri))
    $pen.Dispose()
    # thin dark edge outside the ring
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, $ch.Edge)), ([float]$edge)
    $g.DrawEllipse($pen, [float]($edge / 2), [float]($edge / 2), [float]$outer, [float]$outer)
    $pen.Dispose()
    $disc.Dispose()
    $g.Dispose()

    $out = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $og = [System.Drawing.Graphics]::FromImage($out)
    $og.InterpolationMode = 'HighQualityBicubic'
    $og.PixelOffsetMode = 'HighQuality'
    $og.CompositingQuality = 'HighQuality'
    $og.Clear([System.Drawing.Color]::Transparent)
    $og.DrawImage($big, 0, 0, $size, $size)
    $og.Dispose()
    $big.Dispose()
    return $out
}

# BITMAPINFOHEADER + bottom-up BGRA pixels + 1-bit AND mask (all zero; alpha is used)
function Get-BmpEntry($bmp) {
    $w = $bmp.Width
    $h = $bmp.Height
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write([uint32]40)
    $bw.Write([int32]$w)
    $bw.Write([int32]($h * 2))
    $bw.Write([uint16]1)
    $bw.Write([uint16]32)
    $bw.Write([uint32]0)
    $bw.Write([uint32]0)
    $bw.Write([int32]0)
    $bw.Write([int32]0)
    $bw.Write([uint32]0)
    $bw.Write([uint32]0)
    for ($y = $h - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $bw.Write([byte]$c.B)
            $bw.Write([byte]$c.G)
            $bw.Write([byte]$c.R)
            $bw.Write([byte]$c.A)
        }
    }
    $maskRow = [int]([Math]::Ceiling($w / 32.0) * 4)
    $bw.Write((New-Object byte[] ($maskRow * $h)))
    $bw.Flush()
    return $ms.ToArray()
}

function Get-PngEntry($bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    return $ms.ToArray()
}

function Write-Icon($ch) {
    $full = Open-Source $ch.Full
    $entries = @()
    foreach ($size in $sizes) {
        $bmp = Get-Icon $size $ch $full
        if ($size -ge 256) {
            $data = Get-PngEntry $bmp
        }
        else {
            $data = Get-BmpEntry $bmp
        }
        $bmp.Dispose()
        $entries += , @($size, $data)
    }
    $full.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$entries.Count)
    $offset = 6 + 16 * $entries.Count
    foreach ($e in $entries) {
        $size = $e[0]
        $data = $e[1]
        $dim = $size
        if ($size -ge 256) { $dim = 0 }
        $bw.Write([byte]$dim)
        $bw.Write([byte]$dim)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$data.Length)
        $bw.Write([uint32]$offset)
        $offset += $data.Length
    }
    foreach ($e in $entries) {
        $bw.Write([byte[]]$e[1])
    }
    $bw.Flush()

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $outPath = Join-Path (Resolve-Path $OutDir).Path $ch.Out
    [System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
    '{0}  {1} bytes' -f $outPath, (Get-Item -LiteralPath $outPath).Length
}

$names = if ($Character -eq 'both') { @('claudia', 'anthony') } else { @($Character) }
foreach ($n in $names) { Write-Icon $characters[$n] }

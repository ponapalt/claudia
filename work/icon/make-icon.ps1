# Builds a Windows .ico from a square PNG, in the same layout as ghost/master/icon.ico:
# 16, 24, 32 and 48 px as 32-bit BMP entries, 256 px as a PNG entry.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/icon/make-icon.ps1
#
# By default it builds Anthony's tray icon (ghost/master/icon_anthony.ico) from
# work/icon_a.png. The ghost switches to it with \![set,tasktrayicon] while a Claude Code
# session is waiting for an answer (yaya_claudecode.dic).
#
#   ... make-icon.ps1 -Source work/icon_c.png -Out ghost/master/icon.ico   (Claudia)

param(
    [string]$Source = (Join-Path $PSScriptRoot '..\icon_a.png'),
    [string]$Out = (Join-Path $PSScriptRoot '..\..\ghost\master\icon_anthony.ico')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$sizes = @(16, 24, 32, 48, 256)

# Premultiply first so the color kept under alpha 0 does not bleed into the edges.
$raw = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
$src = New-Object System.Drawing.Bitmap $raw.Width, $raw.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
$g = [System.Drawing.Graphics]::FromImage($src)
$g.DrawImage($raw, 0, 0, $raw.Width, $raw.Height)
$g.Dispose()
$raw.Dispose()

function Get-Scaled($size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $g.DrawImage($src, $rect, 0, 0, $src.Width, $src.Height, 'Pixel', $attr)
    $attr.Dispose()
    $g.Dispose()
    return $bmp
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

$entries = @()
foreach ($size in $sizes) {
    $bmp = Get-Scaled $size
    if ($size -ge 256) {
        $data = Get-PngEntry $bmp
    }
    else {
        $data = Get-BmpEntry $bmp
    }
    $bmp.Dispose()
    $entries += , @($size, $data)
}
$src.Dispose()

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

$outDir = Split-Path -Parent $Out
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path (Resolve-Path $outDir).Path (Split-Path -Leaf $Out)
[System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
'{0}  {1} bytes' -f $outPath, (Get-Item -LiteralPath $outPath).Length

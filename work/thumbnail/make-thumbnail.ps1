<#
.SYNOPSIS
    Draws the ghost thumbnail (thumbnail.png, 560 x 315 by default) in the "soiree"
    style of docs/design-system.md.
.DESCRIPTION
    Night ground with a faint clay glow behind the two characters, a double gold
    hairline frame, the title column on the right with a lozenge divider, and a
    small wax seal in the bottom right corner.
    The characters come from work/surfaces/ (1024 x 1536). Claudia stands 350px
    tall and Anthony at 0.6 of her height, as in the shell.
    The Japanese text is kept in text.txt (UTF-8) so that this script stays ASCII.
    The layout is written in a 720 x 405 design space and scaled to -Width. It is
    drawn at twice the output size and scaled down, which keeps the edges smooth;
    the hairlines are placed on output pixel centers so they stay 1px wide.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File work/thumbnail/make-thumbnail.ps1
#>
[CmdletBinding()]
param(
    [string]$Out = '',
    # output width; the height follows the 16:9 design space
    [int]$Width = 560,
    [string]$Claudia = 'surface05.png',
    [string]$Anthony = 'surface10.png'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = (Resolve-Path (Join-Path $here '..\..')).Path
if (-not $Out) { $Out = Join-Path $root 'thumbnail.png' }
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class ThumbUtil
{
    // bounds of the pixels whose alpha is above the threshold
    public static Rectangle Opaque(Bitmap b, int threshold)
    {
        Rectangle r = new Rectangle(0, 0, b.Width, b.Height);
        BitmapData d = b.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] px = new byte[d.Stride * d.Height];
        Marshal.Copy(d.Scan0, px, 0, px.Length);
        b.UnlockBits(d);
        int x0 = b.Width, y0 = b.Height, x1 = -1, y1 = -1;
        for (int y = 0; y < b.Height; y++)
            for (int x = 0; x < b.Width; x++)
                if (px[y * d.Stride + x * 4 + 3] > threshold)
                {
                    if (x < x0) x0 = x; if (x > x1) x1 = x;
                    if (y < y0) y0 = y; if (y > y1) y1 = y;
                }
        return Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
    }
}
'@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

# --- palette (docs/design-system.md) --------------------------------------
function C($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
$Night        = C 31 18 24
$NightInk     = C 243 230 208
$NightInkSoft = C 184 164 140
$NightGold    = C 201 161 94
$Clay         = C 180 83 47
$Wine         = C 109 31 44
$Vellum       = C 250 245 234

# --- text -----------------------------------------------------------------
$text = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $here 'text.txt'), [System.Text.Encoding]::UTF8)) {
    $i = $line.IndexOf('=')
    if ($i -gt 0) { $text[$line.Substring(0, $i)] = $line.Substring($i + 1) }
}

# --- canvas ---------------------------------------------------------------
$W = 720; $H = 405
$OW = $Width; $OH = [int][Math]::Round($Width * $H / $W)
$S = 2.0 * $OW / $W
# one output pixel in design units, and the design coordinate of output pixel k's center
$Hair = [float]($W / $OW)
function Px([int]$k) { [float](($k + 0.5) * $W / $OW) }
$bmp = New-Object System.Drawing.Bitmap ($OW * 2), ($OH * 2), ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.CompositingQuality = 'HighQuality'
$g.TextRenderingHint = 'AntiAlias'
$g.ScaleTransform($S, $S)
$g.Clear($Night)

# the sources keep a glow color under alpha 0; premultiply before scaling
function Open-Image($path) {
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $path))
    $rect = [ThumbUtil]::Opaque($src, 12)
    $pm = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
    $pg = [System.Drawing.Graphics]::FromImage($pm)
    $pg.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $pg.Dispose()
    $src.Dispose()
    return @($pm, $rect)
}

function Draw-Figure($img, $rect, [float]$cx, [float]$bottom, [float]$height) {
    $w = [float]($rect.Width * $height / $rect.Height)
    $dst = New-Object System.Drawing.RectangleF ($cx - $w / 2), ($bottom - $height), $w, $height
    $srcR = New-Object System.Drawing.RectangleF $rect.X, $rect.Y, $rect.Width, $rect.Height
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $g.DrawImage($img, [System.Drawing.Rectangle]::Round($dst), $srcR.X, $srcR.Y, $srcR.Width, $srcR.Height, 'Pixel', $attr)
    $attr.Dispose()
}

# text with tracking, centered on cx; y is the top of the line box
function Draw-Spaced([string]$s, $font, $color, [float]$cx, [float]$y, [float]$track) {
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    $widths = @()
    foreach ($ch in $s.ToCharArray()) { $widths += $g.MeasureString([string]$ch, $font, 1000, $fmt).Width }
    $total = ($widths | Measure-Object -Sum).Sum + $track * ($s.Length - 1)
    $x = $cx - $total / 2
    $brush = New-Object System.Drawing.SolidBrush $color
    for ($i = 0; $i -lt $s.Length; $i++) {
        $g.DrawString([string]$s[$i], $font, $brush, [float]$x, $y, $fmt)
        $x += $widths[$i] + $track
    }
    $brush.Dispose()
}

function Draw-Lozenge([float]$cx, [float]$cy, [float]$hw, [float]$hh, $color) {
    $pts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF $cx, ($cy - $hh)),
        (New-Object System.Drawing.PointF ($cx + $hw), $cy),
        (New-Object System.Drawing.PointF $cx, ($cy + $hh)),
        (New-Object System.Drawing.PointF ($cx - $hw), $cy))
    $b = New-Object System.Drawing.SolidBrush $color
    $g.FillPolygon($b, $pts)
    $b.Dispose()
}

# --- glow behind the characters -------------------------------------------
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(-40, 10, 500, 420)
$pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pgb.CenterPoint = New-Object System.Drawing.PointF 210, 235
$pgb.CenterColor = [System.Drawing.Color]::FromArgb(34, $Clay)
$pgb.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, $Clay))
$g.FillPath($pgb, $glow)
$pgb.Dispose(); $glow.Dispose()

# --- double frame ---------------------------------------------------------
# outer rule 9px and inner rule 12px from the edge of the output
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, $NightGold)), $Hair
$g.DrawRectangle($pen, (Px 9), (Px 9), ((Px ($OW - 10)) - (Px 9)), ((Px ($OH - 10)) - (Px 9)))
$pen.Color = [System.Drawing.Color]::FromArgb(150, $NightGold)
$g.DrawRectangle($pen, (Px 12), (Px 12), ((Px ($OW - 13)) - (Px 12)), ((Px ($OH - 13)) - (Px 12)))
$pen.Dispose()

# --- characters -----------------------------------------------------------
$c = Open-Image (Join-Path $root "work\surfaces\$Claudia")
$a = Open-Image (Join-Path $root "work\surfaces\$Anthony")
$ground = 380
$ch = 350
Draw-Figure $a[0] $a[1] 330 $ground ($ch * 0.6)
Draw-Figure $c[0] $c[1] 158 ($ground + 2) $ch
$c[0].Dispose(); $a[0].Dispose()

# --- title column ---------------------------------------------------------
$tx = 566
$fKicker = New-Object System.Drawing.Font 'Yu Mincho Demibold', 16, ([System.Drawing.GraphicsUnit]::Pixel)
$fTitle  = New-Object System.Drawing.Font 'Yu Mincho Demibold', 36, ([System.Drawing.GraphicsUnit]::Pixel)
$fLatin  = New-Object System.Drawing.Font 'Palatino Linotype', 15, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
$fQuote  = New-Object System.Drawing.Font 'BIZ UDMincho Medium', 16, ([System.Drawing.GraphicsUnit]::Pixel)
$fFoot   = New-Object System.Drawing.Font 'Palatino Linotype', 13, ([System.Drawing.GraphicsUnit]::Pixel)

Draw-Spaced $text['kicker'] $fKicker $NightGold $tx 104 6
Draw-Spaced $text['title']  $fTitle  $NightInk  $tx 128 4
Draw-Spaced $text['latin']  $fLatin  $NightGold $tx 182 1

# divider: a hairline fading out to both ends, with the lozenges in the middle
$dy = Px ([int][Math]::Floor(219 * $OW / $W))
foreach ($side in @(-1, 1)) {
    $x0 = $tx + $side * 16
    $x1 = $tx + $side * 96
    $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        (New-Object System.Drawing.PointF $x0, $dy), (New-Object System.Drawing.PointF $x1, $dy),
        ([System.Drawing.Color]::FromArgb(220, $NightGold)), ([System.Drawing.Color]::FromArgb(0, $NightGold)))
    $lp = New-Object System.Drawing.Pen $lb, $Hair
    $g.DrawLine($lp, $x0, $dy, $x1, $dy)
    $lp.Dispose(); $lb.Dispose()
}
Draw-Lozenge $tx $dy 5.5 2.6 $NightGold
Draw-Lozenge ($tx - 11) $dy 2.2 1.6 $NightGold
Draw-Lozenge ($tx + 11) $dy 2.2 1.6 $NightGold

Draw-Spaced $text['quote1'] $fQuote $NightInkSoft $tx 240 1
Draw-Spaced $text['quote2'] $fQuote $NightInkSoft $tx 268 1

Draw-Spaced $text['footer'] $fFoot $NightInkSoft $tx 354 0.5

# --- wax seal, the one broken symmetry (bottom right) ----------------------
$sx = 676; $sy = 361; $sr = 15
$seal = New-Object System.Drawing.Drawing2D.GraphicsPath
$n = 36
$pts = New-Object 'System.Drawing.PointF[]' $n
for ($i = 0; $i -lt $n; $i++) {
    $t = 2 * [Math]::PI * $i / $n
    $rr = $sr + 0.9 * [Math]::Sin($t * 5 + 0.7) + 0.5 * [Math]::Sin($t * 9)
    $pts[$i] = New-Object System.Drawing.PointF ([float]($sx + $rr * [Math]::Cos($t))), ([float]($sy + $rr * [Math]::Sin($t)))
}
$seal.AddClosedCurve($pts, 0.5)
$sb = New-Object System.Drawing.SolidBrush $Wine
$g.FillPath($sb, $seal)
$sb.Dispose()
$ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, $Vellum)), 0.8
$g.DrawEllipse($ring, $sx - $sr + 3.5, $sy - $sr + 3.5, 2 * $sr - 7, 2 * $sr - 7)
$ring.Dispose()
$fSeal = New-Object System.Drawing.Font 'Palatino Linotype', 15, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
Draw-Spaced 'C' $fSeal ([System.Drawing.Color]::FromArgb(220, $Vellum)) ($sx + 0.5) ($sy - 9.5) 0
$seal.Dispose()

foreach ($f in @($fKicker, $fTitle, $fLatin, $fQuote, $fFoot, $fSeal)) { $f.Dispose() }
$g.Dispose()

# --- scale down and save as an opaque 24bit PNG ---------------------------
$outBmp = New-Object System.Drawing.Bitmap $OW, $OH, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$og = [System.Drawing.Graphics]::FromImage($outBmp)
$og.InterpolationMode = 'HighQualityBicubic'
$og.PixelOffsetMode = 'HighQuality'
$og.CompositingQuality = 'HighQuality'
$attr = New-Object System.Drawing.Imaging.ImageAttributes
$attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
$og.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $OW, $OH), 0, 0, $bmp.Width, $bmp.Height, 'Pixel', $attr)
$attr.Dispose(); $og.Dispose(); $bmp.Dispose()
$outBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$outBmp.Dispose()
Write-Host ("wrote: {0}" -f $Out)

<#
.SYNOPSIS
    Draws the GitHub social preview (Open Graph image, 1280 x 640) in the "soiree"
    style of docs/design-system.md.
.DESCRIPTION
    The same composition as work/thumbnail/make-thumbnail.ps1, laid out again for
    2:1. GitHub recommends keeping the important details 40pt (80px at 1280 x 640)
    inside the edge, so the faces, the text column and the wax seal stay inside
    the 1120 x 480 safe area. The double frame sits in the margin (34px and 42px
    from the edge, which survives the 1.91:1 crop of some services) and may be cut.
    The hairlines are 2px, since the card is usually shown at about half size.
    The Japanese text is kept in text.txt (UTF-8) so that this script stays ASCII.
    It is drawn at twice the output size and scaled down.
    The image is uploaded by hand in the repository settings (Settings > General >
    Social preview); it is not shipped in the nar (work/ is in .narignore).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File work/ogp/make-ogp.ps1
#>
[CmdletBinding()]
param(
    [string]$Out = '',
    [string]$Claudia = 'surface05.png',
    [string]$Anthony = 'surface10.png',
    # draw the 80px safe area as a guide
    [switch]$Guide
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = (Resolve-Path (Join-Path $here '..\..')).Path
if (-not $Out) { $Out = Join-Path $here 'social-preview.png' }
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class OgpUtil
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

    // night ground with an elliptical glow, ordered-dithered so the 8bit steps
    // of the dark gradient do not show as rings
    public static Bitmap Glow(int w, int h, Color ground, Color glow, float cx, float cy,
                              float rx, float ry, float strength)
    {
        int[] bayer = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
        Bitmap b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] px = new byte[d.Stride * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                double dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
                double r = Math.Sqrt(dx * dx + dy * dy);
                double a = r >= 1 ? 0 : strength * Math.Pow(1 - r, 1.4);
                double t = (bayer[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0;
                int i = y * d.Stride + x * 4;
                px[i]     = (byte)Math.Floor(ground.B + (glow.B - ground.B) * a + t);
                px[i + 1] = (byte)Math.Floor(ground.G + (glow.G - ground.G) * a + t);
                px[i + 2] = (byte)Math.Floor(ground.R + (glow.R - ground.R) * a + t);
                px[i + 3] = 255;
            }
        Marshal.Copy(px, 0, d.Scan0, px.Length);
        b.UnlockBits(d);
        return b;
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
$W = 1280; $H = 640
$S = 2.0
$Hair = [float]2
$bmp = New-Object System.Drawing.Bitmap ($W * 2), ($H * 2), ([System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.CompositingQuality = 'HighQuality'
$g.TextRenderingHint = 'AntiAlias'
$g.ScaleTransform($S, $S)
$g.Clear([System.Drawing.Color]::Transparent)

# the sources keep a glow color under alpha 0; premultiply before scaling
function Open-Image($path) {
    $src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $path))
    $rect = [OgpUtil]::Opaque($src, 12)
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
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $g.DrawImage($img, [System.Drawing.Rectangle]::Round($dst), $rect.X, $rect.Y, $rect.Width, $rect.Height, 'Pixel', $attr)
    $attr.Dispose()
    Write-Host ("figure: x {0:0}-{1:0}, y {2:0}-{3:0}" -f $dst.Left, $dst.Right, $dst.Top, $dst.Bottom)
}

# text with tracking, centered on cx; y is the top of the line box
function Draw-Spaced([string]$s, $font, $color, [float]$cx, [float]$y, [float]$track) {
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    $widths = @()
    foreach ($ch in $s.ToCharArray()) { $widths += $g.MeasureString([string]$ch, $font, 2000, $fmt).Width }
    $total = ($widths | Measure-Object -Sum).Sum + $track * ($s.Length - 1)
    $x = $cx - $total / 2
    Write-Host ("text: x {0:0}-{1:0}, y {2:0}  {3}" -f $x, ($x + $total), $y, $font.Name)
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

# --- double frame (in the margin) -----------------------------------------
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, $NightGold)), $Hair
$g.DrawRectangle($pen, 34, 34, ($W - 68), ($H - 68))
$pen.Color = [System.Drawing.Color]::FromArgb(150, $NightGold)
$g.DrawRectangle($pen, 42, 42, ($W - 84), ($H - 84))
$pen.Dispose()

# --- characters -----------------------------------------------------------
$c = Open-Image (Join-Path $root "work\surfaces\$Claudia")
$a = Open-Image (Join-Path $root "work\surfaces\$Anthony")
$ground = 588
$ch = 500
Draw-Figure $a[0] $a[1] 540 $ground ($ch * 0.6)
Draw-Figure $c[0] $c[1] 290 ($ground + 3) $ch
$c[0].Dispose(); $a[0].Dispose()

# --- title column ---------------------------------------------------------
$tx = 945
$fKicker = New-Object System.Drawing.Font 'Yu Mincho Demibold', 26, ([System.Drawing.GraphicsUnit]::Pixel)
$fTitle  = New-Object System.Drawing.Font 'Yu Mincho Demibold', 66, ([System.Drawing.GraphicsUnit]::Pixel)
$fLatin  = New-Object System.Drawing.Font 'Palatino Linotype', 25, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
$fQuote  = New-Object System.Drawing.Font 'BIZ UDPMincho Medium', 27, ([System.Drawing.GraphicsUnit]::Pixel)
$fFoot   = New-Object System.Drawing.Font 'Palatino Linotype', 21, ([System.Drawing.GraphicsUnit]::Pixel)

Draw-Spaced $text['kicker'] $fKicker $NightGold $tx 128 10
Draw-Spaced $text['title']  $fTitle  $NightInk  $tx 168 8
Draw-Spaced $text['latin']  $fLatin  $NightGold $tx 268 2

# divider: a hairline fading out to both ends, with the lozenges in the middle
$dy = [float]325
foreach ($side in @(-1, 1)) {
    $x0 = $tx + $side * 28
    $x1 = $tx + $side * 170
    $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        (New-Object System.Drawing.PointF $x0, $dy), (New-Object System.Drawing.PointF $x1, $dy),
        ([System.Drawing.Color]::FromArgb(220, $NightGold)), ([System.Drawing.Color]::FromArgb(0, $NightGold)))
    $lp = New-Object System.Drawing.Pen $lb, $Hair
    $g.DrawLine($lp, $x0, $dy, $x1, $dy)
    $lp.Dispose(); $lb.Dispose()
}
Draw-Lozenge $tx $dy 10 4.6 $NightGold
Draw-Lozenge ($tx - 20) $dy 4 2.8 $NightGold
Draw-Lozenge ($tx + 20) $dy 4 2.8 $NightGold

Draw-Spaced $text['quote1'] $fQuote $NightInkSoft $tx 356 1.5
Draw-Spaced $text['quote2'] $fQuote $NightInkSoft $tx 402 1.5

Draw-Spaced $text['footer'] $fFoot $NightInkSoft $tx 506 1

# --- wax seal, the one broken symmetry (bottom right) ----------------------
$sx = 1158; $sy = 516; $sr = 26
$seal = New-Object System.Drawing.Drawing2D.GraphicsPath
$n = 36
$pts = New-Object 'System.Drawing.PointF[]' $n
for ($i = 0; $i -lt $n; $i++) {
    $t = 2 * [Math]::PI * $i / $n
    $rr = $sr + 1.5 * [Math]::Sin($t * 5 + 0.7) + 0.8 * [Math]::Sin($t * 9)
    $pts[$i] = New-Object System.Drawing.PointF ([float]($sx + $rr * [Math]::Cos($t))), ([float]($sy + $rr * [Math]::Sin($t)))
}
$seal.AddClosedCurve($pts, 0.5)
$sb = New-Object System.Drawing.SolidBrush $Wine
$g.FillPath($sb, $seal)
$sb.Dispose()
$ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, $Vellum)), 1.4
$g.DrawEllipse($ring, $sx - $sr + 6, $sy - $sr + 6, 2 * $sr - 12, 2 * $sr - 12)
$ring.Dispose()
$fSeal = New-Object System.Drawing.Font 'Palatino Linotype', 26, ([System.Drawing.FontStyle]::Italic), ([System.Drawing.GraphicsUnit]::Pixel)
Draw-Spaced 'C' $fSeal ([System.Drawing.Color]::FromArgb(220, $Vellum)) ($sx + 1) ($sy - 16.5) 0
$seal.Dispose()

if ($Guide) {
    $gp = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 220, 40, 60)), 1
    $g.DrawRectangle($gp, 80, 80, ($W - 160), ($H - 160))
    $gp.Dispose()
}

foreach ($f in @($fKicker, $fTitle, $fLatin, $fQuote, $fFoot, $fSeal)) { $f.Dispose() }
$g.Dispose()

# --- scale down over the ground and save as an opaque 24bit PNG ---------------------------
# the glow is computed at the output size and dithered there; the drawing is
# laid over it, so the ground pixels keep their dithered values
$outBmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$og = [System.Drawing.Graphics]::FromImage($outBmp)
$ground = [OgpUtil]::Glow($W, $H, $Night, $Clay, 400, 380, 500, 360, 0.16)
$og.DrawImageUnscaled($ground, 0, 0)
$ground.Dispose()
$og.InterpolationMode = 'HighQualityBicubic'
$og.PixelOffsetMode = 'HighQuality'
$og.CompositingQuality = 'HighQuality'
$attr = New-Object System.Drawing.Imaging.ImageAttributes
$attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
$og.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), 0, 0, $bmp.Width, $bmp.Height, 'Pixel', $attr)
$attr.Dispose(); $og.Dispose(); $bmp.Dispose()
$outBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$outBmp.Dispose()
Write-Host ("wrote: {0} ({1:N0} bytes)" -f $Out, (Get-Item $Out).Length)

<#
.SYNOPSIS
    Draws the image files of the Claudia balloons (side version and overhead version).
.DESCRIPTION
    Writes 32bit RGBA PNG files. The balloon geometry follows the SSP default balloon
    ("ssp" / "ssp_vertical") so the coordinate settings of descript.txt carry over:
      side     : canvas 400 x H, body x = 10..390 (380 wide), 9px tail on the left or right.
                 tail center y = H - 115 (sakura) / H - 58 (kero).
      vertical : canvas 383 x (H + 9), body full width, 9px tail at the bottom center.
    The body holds the text the descript.txt files promise:
      s0/s1 9 lines, s2/s3 24 lines, k0/k1 4 lines, k2/k3 9 lines, all 23 glyphs wide.
    At font.height 15 a full width glyph is 15px wide and SSP advances 17px per line,
    and it keeps about 12px free below the last line:
      height = lines * 17 + 53
        (14 top margin, 24 bottom margin, 12 for that free strip, 3 to spare).
    The bottom margin keeps the text clear of the online / SSTP markers, the SSTP
    message and the counter, which sit 10..24px above the bottom edge of the body.
    descript.txt and the other text files are copied from text/ as they are.
    Colors and ornaments follow docs/design-system.md. The tail is a quill point: its
    sides flare out of the body edge and curve in to a fine tip, and a small lozenge
    on the inner rule marks where it leaves the body.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File work/balloon/make-balloon.ps1
#>
[CmdletBinding()]
param(
    # the balloons ship inside the ghost folder; SSP picks them up through
    # shortcuts placed in <SSP>/balloon/
    [string]$SideDir     = '',
    [string]$VerticalDir = '',
    # descript.txt / install.txt / readme.txt are kept here and copied over as they are
    [string]$TextDir = ''
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = (Resolve-Path (Join-Path $here '..\..')).Path
if (-not $SideDir)     { $SideDir     = Join-Path $root 'claudia' }
if (-not $VerticalDir) { $VerticalDir = Join-Path $root 'claudia_vertical' }
if (-not $TextDir)     { $TextDir     = Join-Path $here 'text' }
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

public class Theme
{
    public Color FillTop, FillBottom, Border, Hair, Ink;
    public Color Gems = Color.Empty; // corner gems, Empty = use Hair
    public string Mono = null;      // watermark letter, null = none
    public int MonoAlpha = 28;
    public bool Fancy = false;      // extra lozenges on the top/bottom of the inner frame
    public Color GemAccent = Color.Empty; // bottom-right corner gem only, Empty = same as the others
}

public static class Gen
{
    public static Color C(int r, int g, int b) { return Color.FromArgb(255, r, g, b); }

    // dir: 0 = no tail, 1 = right, 2 = left, 3 = bottom
    // one side of the quill-point tail, from a to b along the path.
    // (ox, oy): unit vector out of the body. (ex, ey): unit vector along the body edge in
    // the direction the path runs. One end of the side is on the edge, the other is the tip.
    static void TailSide(GraphicsPath p, PointF a, PointF b, bool fromEdge, float ox, float oy, float ex, float ey, float tout, float thalf)
    {
        PointF c1, c2;
        if (fromEdge)
        {
            // leaves the edge almost along it, then bends out and narrows to the tip
            c1 = new PointF(a.X + ox * tout * 0.20f + ex * thalf * 0.65f, a.Y + oy * tout * 0.20f + ey * thalf * 0.65f);
            c2 = new PointF(b.X - ox * tout * 0.40f - ex * thalf * 0.08f, b.Y - oy * tout * 0.40f - ey * thalf * 0.08f);
        }
        else
        {
            c1 = new PointF(a.X - ox * tout * 0.40f + ex * thalf * 0.08f, a.Y - oy * tout * 0.40f + ey * thalf * 0.08f);
            c2 = new PointF(b.X + ox * tout * 0.20f - ex * thalf * 0.65f, b.Y + oy * tout * 0.20f - ey * thalf * 0.65f);
        }
        p.AddBezier(a, c1, c2, b);
    }

    static GraphicsPath Body(RectangleF rc, float rad, int dir, float tpos, float tout, float thalf)
    {
        GraphicsPath p = new GraphicsPath();
        float L = rc.Left, T = rc.Top, R = rc.Right, B = rc.Bottom, d = rad * 2;
        p.AddArc(L, T, d, d, 180, 90);
        p.AddArc(R - d, T, d, d, 270, 90);
        if (dir == 1)
        {
            // right edge, the path runs downward
            PointF tip = new PointF(R + tout, tpos);
            TailSide(p, new PointF(R, tpos - thalf), tip, true, 1, 0, 0, 1, tout, thalf);
            TailSide(p, tip, new PointF(R, tpos + thalf), false, 1, 0, 0, 1, tout, thalf);
        }
        p.AddArc(R - d, B - d, d, d, 0, 90);
        if (dir == 3)
        {
            // bottom edge, the path runs to the left
            PointF tip = new PointF(tpos, B + tout);
            TailSide(p, new PointF(tpos + thalf, B), tip, true, 0, 1, -1, 0, tout, thalf);
            TailSide(p, tip, new PointF(tpos - thalf, B), false, 0, 1, -1, 0, tout, thalf);
        }
        p.AddArc(L, B - d, d, d, 90, 90);
        if (dir == 2)
        {
            // left edge, the path runs upward
            PointF tip = new PointF(L - tout, tpos);
            TailSide(p, new PointF(L, tpos + thalf), tip, true, -1, 0, 0, -1, tout, thalf);
            TailSide(p, tip, new PointF(L, tpos - thalf), false, -1, 0, 0, -1, tout, thalf);
        }
        p.CloseFigure();
        return p;
    }

    static GraphicsPath Round(RectangleF rc, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        float d = Math.Max(1f, rad * 2);
        p.AddArc(rc.Left, rc.Top, d, d, 180, 90);
        p.AddArc(rc.Right - d, rc.Top, d, d, 270, 90);
        p.AddArc(rc.Right - d, rc.Bottom - d, d, d, 0, 90);
        p.AddArc(rc.Left, rc.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    static void Gem(Graphics g, float cx, float cy, float w, float h, Color c)
    {
        PointF[] pt = new PointF[] {
            new PointF(cx, cy - h), new PointF(cx + w, cy),
            new PointF(cx, cy + h), new PointF(cx - w, cy) };
        using (SolidBrush b = new SolidBrush(c)) g.FillPolygon(b, pt);
    }

    public static Bitmap Make(int w, int h, RectangleF rc, float rad,
                              int dir, float tpos, float tout, float thalf,
                              Theme t, float hairInset, bool ornament)
    {
        Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);

            using (GraphicsPath p = Body(rc, rad, dir, tpos, tout, thalf))
            {
                using (LinearGradientBrush br = new LinearGradientBrush(
                        new RectangleF(rc.X, rc.Y - 1, rc.Width, rc.Height + 2),
                        t.FillTop, t.FillBottom, 90f))
                    g.FillPath(br, p);

                // watermark monogram, clipped to the body
                if (t.Mono != null)
                {
                    Region keep = g.Clip;
                    g.SetClip(p);
                    float size = Math.Min(rc.Height * 0.62f, 104f);
                    using (FontFamily ff = SafeFamily())
                    using (Font f = new Font(ff, size, FontStyle.Italic, GraphicsUnit.Pixel))
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(t.MonoAlpha, t.Hair)))
                    {
                        SizeF sz = g.MeasureString(t.Mono, f);
                        g.DrawString(t.Mono, f, b,
                            rc.Right - sz.Width + size * 0.10f,
                            rc.Bottom - sz.Height + size * 0.06f);
                    }
                    g.Clip = keep;
                }

                // soft sheen along the top
                float sheenH = Math.Min(rc.Height * 0.45f, 90f);
                if (sheenH > 4f)
                {
                    RectangleF sh = new RectangleF(rc.X, rc.Y, rc.Width, sheenH);
                    Region keep = g.Clip;
                    g.SetClip(p);
                    using (LinearGradientBrush br = new LinearGradientBrush(
                            new RectangleF(sh.X, sh.Y - 1, sh.Width, sh.Height + 1),
                            Color.FromArgb(100, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                        g.FillRectangle(br, sh);
                    g.Clip = keep;
                }

                using (Pen pen = new Pen(t.Border, 2f)) { pen.LineJoin = LineJoin.Round; g.DrawPath(pen, p); }
            }

            // inner gold frame
            RectangleF hr = RectangleF.Inflate(rc, -hairInset, -hairInset);
            float hrad = Math.Max(3f, rad - hairInset);
            using (GraphicsPath hp = Round(hr, hrad))
            using (Pen pen = new Pen(Color.FromArgb(200, t.Hair), 1f))
                g.DrawPath(pen, hp);

            if (ornament)
            {
                // doubled corners: a short arc a little further inside
                float ci = hairInset + 3f;
                RectangleF cr = RectangleF.Inflate(rc, -ci, -ci);
                float cd = Math.Max(2f, rad - ci) * 2;
                using (Pen pen = new Pen(Color.FromArgb(140, t.Hair), 1f))
                {
                    g.DrawArc(pen, cr.Left, cr.Top, cd, cd, 180, 90);
                    g.DrawArc(pen, cr.Right - cd, cr.Top, cd, cd, 270, 90);
                    g.DrawArc(pen, cr.Right - cd, cr.Bottom - cd, cd, cd, 0, 90);
                    g.DrawArc(pen, cr.Left, cr.Bottom - cd, cd, cd, 90, 90);
                }

                // a small gem where each corner arc turns
                float k = hrad * 0.7071f;
                Color gem = Color.FromArgb(230, t.Gems.IsEmpty ? t.Hair : t.Gems);
                Color gemBR = t.GemAccent.IsEmpty ? gem : Color.FromArgb(240, t.GemAccent);
                Gem(g, hr.Left + hrad - k, hr.Top + hrad - k, 2.6f, 2.6f, gem);
                Gem(g, hr.Right - hrad + k, hr.Top + hrad - k, 2.6f, 2.6f, gem);
                Gem(g, hr.Right - hrad + k, hr.Bottom - hrad + k, 2.6f, 2.6f, gemBR);
                Gem(g, hr.Left + hrad - k, hr.Bottom - hrad + k, 2.6f, 2.6f, gem);

                // where the tail leaves the body, a small lozenge sits on the inner rule
                Color tg = Color.FromArgb(235, t.Hair);
                if (dir == 1) Gem(g, hr.Right, tpos, 2.4f, 3.4f, tg);
                if (dir == 2) Gem(g, hr.Left, tpos, 2.4f, 3.4f, tg);
                if (dir == 3) Gem(g, tpos, hr.Bottom, 3.4f, 2.4f, tg);

                if (t.Fancy)
                {
                    float cx = (hr.Left + hr.Right) / 2f;
                    Color loz = Color.FromArgb(235, t.Hair);
                    Gem(g, cx, hr.Top, 5.5f, 2.6f, loz);
                    Gem(g, cx - 11f, hr.Top, 2.2f, 1.6f, loz);
                    Gem(g, cx + 11f, hr.Top, 2.2f, 1.6f, loz);
                    // the bottom centre is where a downward tail comes out
                    if (dir != 3)
                    {
                        Gem(g, cx, hr.Bottom, 5.5f, 2.6f, loz);
                        Gem(g, cx - 11f, hr.Bottom, 2.2f, 1.6f, loz);
                        Gem(g, cx + 11f, hr.Bottom, 2.2f, 1.6f, loz);
                    }
                }
            }
        }
        return bmp;
    }

    // caption baked into the input boxes ("Send", "Teach", ...) and the thumbnail
    public static void Caption(Bitmap b, string text, Color c, float x, float y, float size)
    {
        using (Graphics g = Graphics.FromImage(b))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            using (FontFamily ff = SafeFamily())
            using (Font f = new Font(ff, size, FontStyle.Italic, GraphicsUnit.Pixel))
            using (SolidBrush br = new SolidBrush(c))
                g.DrawString(text, f, br, x, y);
        }
    }

    static FontFamily SafeFamily()
    {
        string[] want = new string[] { "Georgia", "Times New Roman", "Palatino Linotype" };
        foreach (string n in want) { try { return new FontFamily(n); } catch { } }
        return new FontFamily(GenericFontFamilies.Serif);
    }

    public static Bitmap Arrow(bool up, Color fill, Color edge)
    {
        Bitmap b = new Bitmap(8, 8, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(b))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            PointF[] p = up
                ? new PointF[] { new PointF(4f, 0.8f), new PointF(7.4f, 6.6f), new PointF(0.6f, 6.6f) }
                : new PointF[] { new PointF(4f, 7.2f), new PointF(0.6f, 1.4f), new PointF(7.4f, 1.4f) };
            using (SolidBrush br = new SolidBrush(fill)) g.FillPolygon(br, p);
            using (Pen pen = new Pen(edge, 1f)) { pen.LineJoin = LineJoin.Round; g.DrawPolygon(pen, p); }
        }
        return b;
    }

    public static Bitmap Sstp(Color fill, Color edge)
    {
        Bitmap b = new Bitmap(8, 8, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(b))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            PointF[] p = new PointF[] { new PointF(4f, 0.6f), new PointF(7.4f, 4f), new PointF(4f, 7.4f), new PointF(0.6f, 4f) };
            using (SolidBrush br = new SolidBrush(fill)) g.FillPolygon(br, p);
            using (Pen pen = new Pen(edge, 1f)) { pen.LineJoin = LineJoin.Round; g.DrawPolygon(pen, p); }
        }
        return b;
    }

    public static Bitmap Online(int dots, Color ink, Color accent)
    {
        Bitmap b = new Bitmap(48, 14, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(b))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);
            using (FontFamily ff = SafeFamily())
            using (Font f = new Font(ff, 10f, FontStyle.Italic, GraphicsUnit.Pixel))
            using (SolidBrush br = new SolidBrush(ink))
                g.DrawString("connect", f, br, -1f, 1f);
            using (Pen pen = new Pen(accent, 1.4f))
                for (int i = 0; i < dots; i++)
                {
                    float x = 34f + i * 4.5f;
                    g.DrawLine(pen, x, 10.5f, x + 3f, 3.5f);
                }
        }
        return b;
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

function New-Theme {
    param($FillTop, $FillBottom, $Border, $Hair, $Ink, $Mono, $Fancy, $MonoAlpha = 28, $Gems = $null)
    $t = New-Object Theme
    $t.FillTop = $FillTop; $t.FillBottom = $FillBottom
    $t.Border = $Border; $t.Hair = $Hair; $t.Ink = $Ink
    $t.Mono = $Mono; $t.Fancy = $Fancy; $t.MonoAlpha = $MonoAlpha
    if ($null -ne $Gems) { $t.Gems = $Gems }
    return $t
}

function RGB { param($r, $g, $b) return [Gen]::C($r, $g, $b) }

# Colors from docs/design-system.md.
# Claudia: vellum to vellum-deep, clay frame, gold inner rule and gems, watermark C.
$themeS = New-Theme (RGB 250 245 234) (RGB 240 228 206) (RGB 180 83 47) (RGB 185 141 74) (RGB 58 36 25) 'C' $true 28
# Anthony: card, halfway to card-deep at the bottom, tailcoat frame, silver rule and gems,
# one brooch-teal gem in the bottom-right corner.
$themeK = New-Theme (RGB 238 242 250) (RGB 226 233 247) (RGB 38 42 59) (RGB 169 177 196) (RGB 34 38 58) 'A' $false 24
$themeK.GemAccent = RGB 30 116 121
# Input boxes: Claudia's palette, no watermark.
$themeC = New-Theme (RGB 250 245 234) (RGB 240 228 206) (RGB 180 83 47) (RGB 185 141 74) (RGB 58 36 25) $null $false

function Save-Png {
    param($Bitmap, $Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
}

# copies a text file byte for byte, turning bare LF into CRLF (SSP text files are CRLF)
function Copy-AsCrLf {
    param([string]$From, [string]$To)
    $b = [System.IO.File]::ReadAllBytes($From)
    $out = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $b.Length; $i++) {
        if ($b[$i] -eq 10 -and ($i -eq 0 -or $b[$i - 1] -ne 13)) { $out.Add([byte]13) }
        $out.Add($b[$i])
    }
    [System.IO.File]::WriteAllBytes($To, $out.ToArray())
}

# descript.txt etc. from text/<folder name>/, plus the kero override under each name
function Copy-TextFiles {
    param([string]$Dir, [string[]]$KeroFiles)
    $src = Join-Path $TextDir (Split-Path $Dir -Leaf)
    if (-not (Test-Path $src)) { throw "no text folder: $src" }
    foreach ($f in Get-ChildItem -Path $src -Filter *.txt -File) {
        Copy-AsCrLf $f.FullName (Join-Path $Dir $f.Name)
    }
    $kero = Join-Path $TextDir 'kero-override.txt'
    foreach ($n in $KeroFiles) { Copy-AsCrLf $kero (Join-Path $Dir $n) }
}

# --- parts shared by both versions --------------------------------------
function Build-Common {
    param([string]$Dir)
    # the caption of each input box is part of the image, as in the SSP default balloon
    $captions = @('Send', 'Communicate', 'Teach', 'Input', 'Address')
    $capColor = [System.Drawing.Color]::FromArgb(235, 180, 83, 47)
    for ($i = 0; $i -lt $captions.Count; $i++) {
        $rc = New-Object System.Drawing.RectangleF(1.0, 1.0, 380.0, 46.0)
        $bm = [Gen]::Make(382, 48, $rc, 10.0, 0, 0.0, 0.0, 0.0, $themeC, 4.0, $false)
        [Gen]::Caption($bm, $captions[$i], $capColor, 11.0, 1.0, 12.0)
        Save-Png $bm (Join-Path $Dir "balloonc$i.png")
    }

    $inkS = RGB 180 83 47
    $edgeS = RGB 140 59 31
    $inkK = RGB 74 82 112
    $edgeK = RGB 38 42 59
    $gold = RGB 185 141 74
    $silver = RGB 169 177 196

    Save-Png ([Gen]::Arrow($true, $inkS, $edgeS)) (Join-Path $Dir 'arrow0.png')
    Save-Png ([Gen]::Arrow($false, $inkS, $edgeS)) (Join-Path $Dir 'arrow1.png')
    Save-Png ([Gen]::Arrow($true, $inkK, $edgeK)) (Join-Path $Dir 'arrowb0.png')
    Save-Png ([Gen]::Arrow($false, $inkK, $edgeK)) (Join-Path $Dir 'arrowb1.png')
    Save-Png ([Gen]::Sstp($gold, $edgeS)) (Join-Path $Dir 'sstp.png')
    Save-Png ([Gen]::Sstp($silver, $edgeK)) (Join-Path $Dir 'sstpb.png')

    for ($i = 0; $i -lt 4; $i++) {
        Save-Png ([Gen]::Online($i, $inkS, $gold)) (Join-Path $Dir "online$i.png")
        Save-Png ([Gen]::Online($i, $inkK, $silver)) (Join-Path $Dir "onlineb$i.png")
    }
    Save-Png ([Gen]::Online(3, $inkS, $gold)) (Join-Path $Dir 'online.png')
    Save-Png ([Gen]::Online(3, $inkK, $silver)) (Join-Path $Dir 'onlineb.png')
}

# thumbnail for the balloon list: balloons0 with the name written in it
function Build-Thumbnail {
    param([string]$Dir)
    $src = [System.Drawing.Image]::FromFile((Join-Path $Dir 'balloons0.png'))
    $tb = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($tb)
    $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $g.Dispose()
    $src.Dispose()
    [Gen]::Caption($tb, 'Claudia', [System.Drawing.Color]::FromArgb(230, 180, 83, 47), 26.0, 20.0, 34.0)
    [Gen]::Caption($tb, 'et Anthony', [System.Drawing.Color]::FromArgb(210, 107, 78, 61), 30.0, 58.0, 18.0)
    Save-Png $tb (Join-Path $Dir 'thumbnail.png')
}

# --- side version -------------------------------------------------------
function Build-Side {
    param([string]$Dir)
    New-Item -ItemType Directory -Force $Dir | Out-Null
    $rad = 14.0
    # name, height, theme, tail offset from the bottom, tail direction
    $specs = @(
        , @('balloons0', 206, $themeS, 115, 1)
        , @('balloons1', 206, $themeS, 115, 2)
        , @('balloons2', 461, $themeS, 115, 1)
        , @('balloons3', 461, $themeS, 115, 2)
        , @('balloonk0', 121, $themeK, 58, 1)
        , @('balloonk1', 121, $themeK, 58, 2)
        , @('balloonk2', 206, $themeK, 58, 1)
        , @('balloonk3', 206, $themeK, 58, 2)
    )
    foreach ($s in $specs) {
        $h = [int]$s[1]
        $rc = New-Object System.Drawing.RectangleF(10.0, 1.0, 380.0, ($h - 2.0))
        $cy = [float]($h - [int]$s[3])
        $bm = [Gen]::Make(400, $h, $rc, $rad, [int]$s[4], $cy, 8.0, 11.0, $s[2], 6.0, $true)
        Save-Png $bm (Join-Path $Dir ($s[0] + '.png'))
    }
    Build-Common $Dir
    Build-Thumbnail $Dir
    Copy-TextFiles $Dir @('balloonk0s.txt', 'balloonk1s.txt', 'balloonk2s.txt', 'balloonk3s.txt')
}

# --- overhead (vertical tail) version -----------------------------------
function Build-Vertical {
    param([string]$Dir)
    New-Item -ItemType Directory -Force $Dir | Out-Null
    $rad = 14.0
    $specs = @(
        , @('balloons0', 206, $themeS)
        , @('balloons2', 461, $themeS)
        , @('balloonk0', 121, $themeK)
        , @('balloonk2', 206, $themeK)
    )
    foreach ($s in $specs) {
        $bh = [int]$s[1]
        $h = $bh + 9
        $rc = New-Object System.Drawing.RectangleF(1.0, 1.0, 381.0, ($bh - 2.0))
        $bm = [Gen]::Make(383, $h, $rc, $rad, 3, 191.0, 8.0, 11.0, $s[2], 6.0, $true)
        Save-Png $bm (Join-Path $Dir ($s[0] + '.png'))
    }
    Build-Common $Dir
    Build-Thumbnail $Dir
    Copy-TextFiles $Dir @('balloonk0s.txt', 'balloonk2s.txt')
}

Build-Side $SideDir
Build-Vertical $VerticalDir
Write-Host ("wrote: {0}" -f $SideDir)
Write-Host ("wrote: {0}" -f $VerticalDir)

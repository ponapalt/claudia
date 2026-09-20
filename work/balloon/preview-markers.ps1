<#
.SYNOPSIS
    Draws the scroll arrows and the online / SSTP markers at the coordinates
    descript.txt gives them, to check they do not sit on the frame.
#>
[CmdletBinding()]
param([string]$Dir, [string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Get-Num {
    param([string]$Text, [string]$Key)
    foreach ($l in $Text -split "`r?`n") {
        if ($l -match "^\s*$([regex]::Escape($Key)),\s*(-?\d+)\s*$") { return [int]$Matches[1] }
    }
    throw "not found: $Key"
}

$d = Get-Content (Join-Path $Dir 'descript.txt') -Raw -Encoding UTF8
$base = [System.Drawing.Image]::FromFile((Join-Path $Dir 'balloons0.png'))
$bmp = New-Object System.Drawing.Bitmap(($base.Width + 40), ($base.Height + 40), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, 64, 78, 92))
$g.DrawImage($base, 20, 20, $base.Width, $base.Height)

function Place {
    param([string]$File, [int]$X, [int]$Y)
    $img = [System.Drawing.Image]::FromFile((Join-Path $Dir $File))
    $px = if ($X -lt 0) { $base.Width + $X } else { $X }
    $py = if ($Y -lt 0) { $base.Height + $Y } else { $Y }
    $g.DrawImage($img, ($px + 20), ($py + 20), $img.Width, $img.Height)
    $img.Dispose()
}

Place 'arrow0.png' (Get-Num $d 'arrow0.x') (Get-Num $d 'arrow0.y')
Place 'arrow1.png' (Get-Num $d 'arrow1.x') (Get-Num $d 'arrow1.y')
Place 'online3.png' (Get-Num $d 'onlinemarker.x') (Get-Num $d 'onlinemarker.y')

# the counter number, right aligned at number.xr
$nf = New-Object System.Drawing.Font('Tahoma', (Get-Num $d 'number.font.height'), [System.Drawing.GraphicsUnit]::Pixel)
$nx = $base.Width + (Get-Num $d 'number.xr')
$ny = $base.Height + (Get-Num $d 'number.y')
$g.DrawString('888', $nf, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 150, 108, 58))), ($nx + 20), ($ny + 20))

# text area from validrect, so the margins are visible
$vl = Get-Num $d 'validrect.left'; $vt = Get-Num $d 'validrect.top'
$vr = Get-Num $d 'validrect.right'; $vb = Get-Num $d 'validrect.bottom'
$rx = if ($vl -lt 0) { $base.Width + $vl } else { $vl }
$ry = if ($vt -lt 0) { $base.Height + $vt } else { $vt }
$rr = if ($vr -lt 0) { $base.Width + $vr } else { $vr }
$rb = if ($vb -lt 0) { $base.Height + $vb } else { $vb }
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 0, 160, 255), 1)
$pen.DashStyle = 'Dash'
$g.DrawRectangle($pen, ($rx + 20), ($ry + 20), ($rr - $rx), ($rb - $ry))

$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $base.Dispose()
Write-Host "wrote: $Out"

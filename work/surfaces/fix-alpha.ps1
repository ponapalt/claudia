# Makes the almost opaque pixels of the shell images fully opaque: every alpha from
# -Threshold (240) to 254 becomes 255. The colors are not touched.
#
# The image generator leaves the inside of the characters at alpha 252-253 instead of 255,
# so the desktop shows through the whole body by about 1%, and parts cut out of them
# (element / animation of surfaces.txt) inherit it. Pixels below the threshold (the
# antialiased edges and the feathered edges of parts) keep their alpha.
#
# By default it fixes the full-size sources (work/surfaces/*.png) and the shell images
# (shell/master/*.png) in place; the files are in git, so compare and revert there.
# Files that need no change are not rewritten.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/surfaces/fix-alpha.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File work/surfaces/fix-alpha.ps1
#   ... fix-alpha.ps1 -Path shell/master/surface0.png   (only these files or folders)

param(
    [string[]]$Path,
    [ValidateRange(1, 255)]
    [int]$Threshold = 240,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $root 'tools/lib/common.ps1')
. (Join-Path $root 'tools/lib/image-engine.ps1')
Import-DevkitImageEngine

if (-not ('ClaudiaFixAlpha' -as [type])) {
    Add-Type -ReferencedAssemblies ([GhostDevkit.Imaging.RgbaImage].Assembly.Location) -TypeDefinition @'
public static class ClaudiaFixAlpha
{
    // Sets alpha threshold..254 to 255 and returns how many pixels changed.
    public static int Run(GhostDevkit.Imaging.RgbaImage img, int threshold)
    {
        byte[] p = img.Pixels;
        int changed = 0;
        for (int i = 3; i < p.Length; i += 4)
        {
            if (p[i] >= threshold && p[i] < 255) { p[i] = 255; changed++; }
        }
        return changed;
    }
}
'@
}

if (-not $Path) { $Path = @('work/surfaces', 'shell/master') }
$files = @()
foreach ($item in @($Path | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
    $full = if ([IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $root $item }
    if (Test-Path -LiteralPath $full -PathType Container) {
        $files += @(Get-ChildItem -LiteralPath $full -Filter '*.png' -File | Sort-Object Name | ForEach-Object { $_.FullName })
    } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
        $files += (Resolve-Path -LiteralPath $full).ProviderPath
    } else {
        throw "not found: $item"
    }
}

$total = 0
foreach ($file in $files) {
    $img = [GhostDevkit.Imaging.ImageIO]::Load($file)
    $changed = [ClaudiaFixAlpha]::Run($img, $Threshold)
    $name = $file.Substring($root.Length).TrimStart('\', '/')
    if ($changed -eq 0) {
        Write-Host "  $name`: no change"
        continue
    }
    $total += $changed
    if ($DryRun) {
        Write-Host "  $name`: $changed pixel(s) would become opaque"
    } else {
        [GhostDevkit.Imaging.ImageIO]::Save($img, $file)
        Write-Host "  $name`: $changed pixel(s) made opaque"
    }
}
$verb = if ($DryRun) { 'would change' } else { 'changed' }
Write-Host "fix-alpha: $verb $total pixel(s) in $($files.Count) file(s) (alpha $Threshold-254 -> 255)"

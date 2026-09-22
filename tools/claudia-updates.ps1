<#
.SYNOPSIS
    Writes all network update files of Claudia: the ghost and the two bundled balloons.
.DESCRIPTION
    Not part of the development kit; specific to this ghost. Run it before every commit that changes shipped files.
    - ghost:            updates2.dau / updates.txt at the repository root (tools/build-nar.ps1 -UpdateOnly)
    - claudia/:          updates2.dau / updates.txt inside the balloon folder
    - claudia_vertical/: updates2.dau / updates.txt inside the balloon folder
    The balloons are excluded from the ghost update by .updateignore, and each balloon is updated from its own
    homeurl (descript.txt). SSP leaves its output files out of the update data.
    Exit codes: 0 = OK, 1 = failed, 3 = ssp.exe was not found.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/claudia-updates.ps1
#>
[CmdletBinding()]
param(
    [string]$SspPath,
    # Seconds to wait for SSP to write each file.
    [int]$TimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
Initialize-DevkitConsole

$root = $DevkitRoot
$balloons = @('claudia', 'claudia_vertical')

# --- ghost ---------------------------------------------------------------------------------
$ghostArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'build-nar.ps1'),
    '-UpdateOnly', '-OutFile', (Join-Path $root 'claudia.nar'), '-TimeoutSeconds', $TimeoutSeconds)
if ($SspPath) { $ghostArgs += @('-SspPath', $SspPath) }
& powershell @ghostArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "claudia-updates: FAILED - the ghost update files were not written (build-nar exit code $LASTEXITCODE)"
    exit $LASTEXITCODE
}

# --- balloons ------------------------------------------------------------------------------
$ssp = Resolve-SspPath $SspPath
if (-not $ssp) {
    Write-Host 'claudia-updates: ssp.exe was not found. Set the SSP_PATH environment variable or create tools/local.json.'
    exit 3
}

foreach ($balloon in $balloons) {
    $dir = Join-Path $root $balloon
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'descript.txt') -PathType Leaf)) {
        Write-Host "claudia-updates: FAILED - $balloon/descript.txt was not found"
        exit 1
    }
    if (-not (Get-DevkitDescriptValue (Join-Path $dir 'descript.txt') 'homeurl')) {
        Write-Host "claudia-updates: note - $balloon/descript.txt has no homeurl, so the balloon cannot be updated"
    }
    foreach ($name in @('updates2.dau', 'updates.txt')) {
        $out = Join-Path $dir $name
        $arguments = @('--offline-tool', 'updatedata', '--target-dir', $dir, '--output', $out)
        $result = Invoke-DevkitProcess -FilePath $ssp.Path -Arguments $arguments -TimeoutSeconds $TimeoutSeconds
        if ($result.TimedOut) {
            Write-Host "claudia-updates: FAILED - SSP did not finish $balloon/$name within $TimeoutSeconds seconds"
            exit 1
        }
        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $out -PathType Leaf)) {
            Write-Host "claudia-updates: FAILED - SSP could not write $balloon/$name (ssp.exe exit code $($result.ExitCode))"
            exit 1
        }
        $sizeKb = [math]::Round((Get-Item -LiteralPath $out).Length / 1KB)
        Write-Host "claudia-updates: wrote $balloon/$name ($sizeKb KB)"
    }
}
exit 0

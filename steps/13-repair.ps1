# Opt-in Windows Update repair. Only runs with -RepairWindows, because the
# component store repair and cache reset take 30 minutes or more and rename
# system folders.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliRepairWindows -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'Windows Update repair skipped. Use -RepairWindows to run it.'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'Repair needs admin. Run from an elevated shell.'
    return
}

Write-Log 'repair: DISM component store check and repair'
& dism.exe /Online /Cleanup-Image /RestoreHealth
if ($LASTEXITCODE -ne 0) { Write-Warn ("DISM exited {0}. Continue with SFC." -f $LASTEXITCODE) }
else { Write-Ok 'DISM component store repair finished' }

Write-Log 'repair: SFC system file check'
& sfc.exe /scannow
if ($LASTEXITCODE -ne 0) { Write-Warn ("SFC exited {0}." -f $LASTEXITCODE) }
else { Write-Ok 'SFC finished' }

Write-Log 'repair: reset the Windows Update cache'
foreach ($service in @('wuauserv', 'bits', 'cryptsvc')) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
}
foreach ($folder in @("$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2")) {
    if (Test-Path $folder) {
        $backup = "$folder.old"
        if (Test-Path $backup) { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue }
        Rename-Item -LiteralPath $folder -NewName (Split-Path -Leaf $backup) -ErrorAction SilentlyContinue
    }
}
foreach ($service in @('cryptsvc', 'bits', 'wuauserv')) {
    Start-Service -Name $service -ErrorAction SilentlyContinue
}
Write-Ok 'Windows Update cache reset. Restart, then run: .\bootstrap.ps1 -From 15-updates'
Write-Warn 'If the update still fails, upgrade straight to Windows 11 with the Installation Assistant.'

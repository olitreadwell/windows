# Preflight: record hardware, generate a battery report, create a restore point.
Set-StrictMode -Version 2.0

$info = Get-MachineInfo
$stateDir = Get-StateDir
$info | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $stateDir 'system-info.json') -Encoding UTF8

Write-Ok ("recorded machine: {0} {1} / {2}" -f $info.Manufacturer, $info.Model, $info.CpuName)
Write-Log ("windows support: {0}" -f $info.WindowsSupport)

if ($info.SystemDriveFreeGb -lt 20) {
    Write-Warn ("only {0} GB free on {1}:. Windows updates need room." -f $info.SystemDriveFreeGb, $env:SystemDrive)
}
else {
    Write-Ok ("free space: {0} GB" -f $info.SystemDriveFreeGb)
}

$batteryReport = Join-Path $stateDir 'battery-report.html'
& powercfg /batteryreport /output $batteryReport | Out-Null
if (Test-Path $batteryReport) {
    Write-Ok ("battery report: {0}" -f $batteryReport)
}
else {
    Write-Warn 'battery report was not written'
}

try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer -Description 'oli-windows bootstrap' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Ok 'system restore point created'
}
catch {
    Write-Warn ("restore point not created: {0}" -f $_.Exception.Message)
    Write-Warn 'Enable System Protection manually before the next run if you want a rollback point.'
}

if ($info.BuildNumber -lt 22000) {
    Write-Warn 'Windows 10 support ended 2025-10-14.'
    Write-Warn 'Consumer ESU runs through 2027-10-12. Enrol in Settings > Update & Security > Windows Update.'
    Write-Warn 'Check Windows 11 eligibility before deciding: https://aka.ms/GetPCHealthCheckApp'
    if ($info.Windows11Blockers.Count -gt 0) {
        Write-Warn ("Windows 11 blockers: {0}" -f ($info.Windows11Blockers -join '; '))
    }
}

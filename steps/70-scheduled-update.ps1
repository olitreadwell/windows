# Opt-in weekly update task. Only runs with -ScheduleUpdate.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliScheduleUpdate -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'weekly update task skipped. Use -ScheduleUpdate to create it.'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'Registering a scheduled task needs admin.'
    return
}

$taskName = 'oli-windows-update'
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Ok 'weekly update task already registered'
    return
}

$updateScript = Join-Path $HOME 'bin/update.ps1'
if (-not (Test-Path $updateScript)) {
    Write-Warn 'update.ps1 is missing. Run: .\bootstrap.ps1 -Only 40-dotfiles'
    return
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $updateScript)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '10:00'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd
$principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -LogonType Interactive -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Weekly winget, mise and gh extension update' -Force | Out-Null
    Write-Ok 'weekly update task registered for Sunday 10:00'
}
catch {
    Write-Warn ("scheduled task failed: {0}" -f $_.Exception.Message)
}

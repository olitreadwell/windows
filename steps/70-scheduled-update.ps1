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

# Resolve the account by SID. A name like "DOMAIN\First Last" fails to map in
# Register-ScheduledTask on some Windows 10 builds with error 0x80070534.
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
$principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Weekly winget, mise and gh extension update' -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Fail ("scheduled task failed: {0}" -f $_.Exception.Message)
}

$registered = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $registered) {
    Write-Fail 'scheduled task did not register'
}
Write-Ok ("weekly update task registered for Sunday 10:00 ({0})" -f $registered.State)

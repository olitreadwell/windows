# Opt-in Windows 10 22H2 upgrade. Downloads Microsoft's Update Assistant and
# runs it, so the upgrade does not depend on Windows Update succeeding.
# When a restart is pending it resets the update state, schedules a one-time
# elevated resume at next logon, and restarts, so the whole path is one command.
# Only runs with -Windows10.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliWindows10 -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'Windows 10 22H2 upgrade skipped. Use -Windows10 to run it.'
    return
}

$build = [Environment]::OSVersion.Version.Build
if ($build -ge 19045) {
    Write-Ok 'already on Windows 10 22H2'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'Windows 10 upgrade needs admin. Run from an elevated shell.'
    return
}

$taskName = 'OliWindows10Upgrade'
$resumeFlag = Join-Path $global:OliStateDir 'win10-resume.flag'

# The resume task fired; it is one-shot, so remove it before doing anything.
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log 'resume task removed'
}

if (Test-RebootPending -and -not (Test-Path $resumeFlag)) {
    Write-Warn 'A restart is pending, which is what keeps the stuck 25 percent install retrying.'
    Reset-WindowsUpdateState -Reason 'stuck update reset' | Out-Null
    Set-Content -Path $resumeFlag -Value (Get-Date).ToString('o') -Encoding UTF8

    $bootstrap = Join-Path $global:OliRepoRoot 'bootstrap.ps1'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Only 16-win10 -Windows10 -Yes' -f $bootstrap
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)
    $principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -RunLevel Highest -LogonType Interactive
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Ok 'scheduled the upgrade to continue automatically after the next sign-in'

    if ($global:OliNoReboot) {
        Write-Warn 'NoReboot set. Restart yourself, then the upgrade starts at sign-in.'
        return
    }
    Write-Warn 'Restarting in 45 seconds. Save your work. Cancel with: shutdown /a'
    & shutdown.exe /r /t 45 /c "Windows 10 upgrade continues after restart"
    return
}

if (Test-Path $resumeFlag) {
    Remove-Item -LiteralPath $resumeFlag -Force -ErrorAction SilentlyContinue
    Write-Log 'resuming the upgrade after the restart'
}

$freeGb = [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
if ($freeGb -lt 20) {
    Write-Fail ("only {0} GB free; the upgrade needs about 20 GB" -f $freeGb)
}

$machine = Get-MachineInfo
Write-Log ("upgrading: {0} {1}, build {2}" -f $machine.Manufacturer, $machine.Model, $build)

if (-not $global:OliAssumeYes) {
    Write-Warn 'This downloads Microsoft''s Windows 10 Update Assistant and starts an in-place upgrade.'
    Write-Warn 'Windows restarts several times. Save your work first.'
    $answer = Read-Host 'Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Warn 'Upgrade cancelled'
        return
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$downloads = Join-Path $HOME 'Downloads'
if (-not (Test-Path $downloads)) { New-Item -ItemType Directory -Path $downloads -Force | Out-Null }
$installer = Join-Path $downloads 'Windows10UpdateAssistant.exe'

try {
    Write-Log 'downloading the Windows 10 Update Assistant'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?LinkID=799445' -OutFile $installer -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Fail ("download failed: {0}. Manual fallback: https://www.microsoft.com/software-download/windows10" -f $_.Exception.Message)
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $installer).Length / 1MB, 1)
if ($sizeMb -lt 2) {
    Write-Fail ("downloaded file is only {0} MB, which is not the assistant. Delete it and try again." -f $sizeMb)
}

$signature = Get-AuthenticodeSignature -FilePath $installer -ErrorAction SilentlyContinue
if (-not $signature -or $signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
    Write-Fail 'assistant signature is not a valid Microsoft signature. Refusing to run it.'
}
Write-Ok ("downloaded and verified: {0} ({1} MB)" -f $installer, $sizeMb)

Write-Log 'starting the Update Assistant. It shows its own progress window.'
$process = Start-Process -FilePath $installer -Verb RunAs -Wait -PassThru

$newBuild = [Environment]::OSVersion.Version.Build
if ($newBuild -ge 19045) {
    Write-Ok 'Windows 10 22H2 installed'
    return
}

Write-Warn ("assistant exited {0}; build is still {1}" -f $process.ExitCode, $newBuild)
Write-Warn 'Manual fallback: https://www.microsoft.com/software-download/windows10, download the Media Creation Tool or ISO.'

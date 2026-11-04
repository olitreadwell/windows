#Requires -Version 5.1
<#
.SYNOPSIS
Read-only diagnosis of a Windows Update that is stuck or failing.

.DESCRIPTION
Collects version, pending reboot, service state, disk space, recent update
errors and setup logs. It changes nothing. Run it in an elevated PowerShell
window so DISM can report component store health.

.EXAMPLE
.\scripts\Diagnose-WindowsUpdate.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
}

Write-Section 'Windows version'
$version = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Host ("  {0} {1} build {2}" -f $version.Caption, $version.Version, $version.BuildNumber)

$displayVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
if ($displayVersion) { Write-Host ("  display version: {0}" -f $displayVersion) }

Write-Section 'Pending reboot'
$rebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)
$pending = $false
foreach ($key in $rebootKeys) {
    if (Test-Path $key) { $pending = $true; Write-Host ("  pending: {0}" -f $key) }
}
if (-not $pending) { Write-Host '  no pending reboot marker' }
Write-Host '  A pending reboot blocks every later update attempt.'

Write-Section 'Services'
foreach ($name in @('wuauserv', 'bits', 'cryptsvc', 'msiserver', 'TrustedInstaller')) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service) { Write-Host ("  {0,-18} {1,-8} start: {2}" -f $service.Name, $service.Status, $service.StartType) }
    else { Write-Host ("  {0,-18} missing" -f $name) }
}

Write-Section 'Disk space'
foreach ($drive in Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3') {
    $freeGb = [math]::Round($drive.FreeSpace / 1GB, 1)
    $sizeGb = [math]::Round($drive.Size / 1GB, 1)
    Write-Host ("  {0} {1} GB free of {2} GB" -f $drive.DeviceID, $freeGb, $sizeGb)
}
Write-Host '  A feature update needs about 20 GB free on the system drive.'

$recovery = Get-Partition -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'Recovery' }
if ($recovery) {
    foreach ($partition in $recovery) {
        $sizeMb = [math]::Round($partition.Size / 1MB)
        Write-Host ("  recovery partition {0}: {1} MB" -f $partition.PartitionNumber, $sizeMb)
        if ($sizeMb -lt 500) { Write-Host '  A recovery partition under 500 MB can block feature updates.' }
    }
}

Write-Section 'Component store'
if (Get-Command dism.exe -ErrorAction SilentlyContinue) {
    $dism = & dism.exe /Online /Cleanup-Image /CheckHealth 2>&1
    $dism | Select-Object -Last 6 | ForEach-Object { Write-Host ("  {0}" -f $_) }
}
else {
    Write-Host '  dism.exe is missing from PATH'
}

Write-Section 'Recent update events'
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-WindowsUpdateClient/Operational'
        Level     = 2, 3
        StartTime = (Get-Date).AddDays(-14)
    } -MaxEvents 12 -ErrorAction Stop
    foreach ($event in $events) {
        Write-Host ("  {0:yyyy-MM-dd HH:mm} {1}" -f $event.TimeCreated, $event.Message.Split("`n")[0])
    }
}
catch {
    Write-Host '  no recent error or warning events in the update log'
}

Write-Section 'Setup logs'
$logs = @(
    'C:\$WINDOWS.~BT\Sources\Panther\setuperr.log',
    'C:\Windows\Panther\setuperr.log'
)
foreach ($log in $logs) {
    if (Test-Path -LiteralPath $log) {
        $item = Get-Item -LiteralPath $log
        Write-Host ("  {0} last written {1:yyyy-MM-dd HH:mm}" -f $log, $item.LastWriteTime)
        Get-Content -LiteralPath $log -Tail 5 | ForEach-Object { Write-Host ("    {0}" -f $_) }
    }
}

Write-Section 'What to try, in order'
Write-Host '  1. Restart, then open Settings > Update & Security > Windows Update and check again.'
Write-Host '  2. Free space on C: until at least 20 GB is available.'
Write-Host '  3. Run these two repairs in an elevated PowerShell, then restart:'
Write-Host '       DISM /Online /Cleanup-Image /RestoreHealth'
Write-Host '       SFC /Scannow'
Write-Host '  4. Reset the update cache only if the repairs fail:'
Write-Host '       net stop wuauserv; net stop bits; net stop cryptsvc'
Write-Host '       Rename-Item C:\Windows\SoftwareDistribution SoftwareDistribution.old'
Write-Host '       Rename-Item C:\Windows\System32\catroot2 catroot2.old'
Write-Host '       net start cryptsvc; net start bits; net start wuauserv'
Write-Host '  5. Read the exact error code from Settings and search it with the KB number.'
Write-Host ''
Write-Host 'This script changed nothing.' -ForegroundColor Green

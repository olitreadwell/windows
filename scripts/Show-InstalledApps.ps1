#Requires -Version 5.1
<#
.SYNOPSIS
List installed apps, their versions, install folders and Start menu entries.

.DESCRIPTION
winget can report success for a package that installed somewhere unusual or
without a Start menu shortcut. This reads the uninstall registry and the
Start menu index so the result is visible instead of assumed.
#>
[CmdletBinding()]
param([string]$Filter)

Set-StrictMode -Version 2.0

$paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$apps = @()
foreach ($path in $paths) {
    $apps += Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName } |
        ForEach-Object {
            [pscustomobject]@{
                Name    = $_.DisplayName
                Version = $_.DisplayVersion
                Where   = $_.InstallLocation
            }
        }
}

if ($Filter) { $apps = @($apps | Where-Object { $_.Name -match $Filter }) }
$apps = @($apps | Sort-Object Name -Unique)

Write-Host ''
Write-Host ("installed: {0}" -f $apps.Count) -ForegroundColor Cyan
$apps | Format-Table Name, Version, Where -AutoSize

Write-Host ''
Write-Host 'Start menu entries' -ForegroundColor Cyan
$startApps = @(Get-StartApps | Sort-Object Name)
if ($Filter) { $startApps = @($startApps | Where-Object { $_.Name -match $Filter }) }
$startApps | Format-Table Name -AutoSize

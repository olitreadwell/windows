# Windows Update. Installs security and quality updates. Feature upgrades,
# including Windows 11, stay a human decision.
Set-StrictMode -Version 2.0

if (-not (Test-IsAdmin)) {
    Write-Warn 'Windows Update needs admin. Run from an elevated shell.'
    return
}

if (Test-RebootPending) {
    Write-Fail 'A restart is already pending. Restart, then run: .\bootstrap.ps1 -From 15-updates'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$module = Get-Module -ListAvailable -Name PSWindowsUpdate
if (-not $module) {
    Write-Log 'installing PSWindowsUpdate module'
    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
        if (-not $nuget) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -AllowClobber -ErrorAction Stop
        Write-Ok 'PSWindowsUpdate installed'
    }
    catch {
        Write-Warn ("PSWindowsUpdate install failed: {0}" -f $_.Exception.Message)
        Write-Warn 'Open Settings > Update & Security > Windows Update and install everything by hand.'
        Write-Fail 'Windows Update could not run. Use -SkipUpdates to provision the rest, then repair Windows Update.'
    }
}

Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
if (-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)) {
    Write-Fail 'Get-WindowsUpdate is unavailable. Use -SkipUpdates to provision the rest, or update by hand in Settings.'
}

$upgrades = @()
try {
    $upgrades = @(Get-WindowsUpdate -Category 'Upgrades' -ErrorAction Stop)
}
catch {
    Write-Warn ("upgrade query failed: {0}" -f $_.Exception.Message)
}

if ($upgrades.Count -gt 0) {
    Write-Warn ("{0} feature upgrade(s) are offered. This script will not install them." -f $upgrades.Count)
    Write-Warn 'Upgrade to Windows 11 deliberately with: .\bootstrap.ps1 -Windows11'
}

$pending = @()
try {
    $pending = @(Get-WindowsUpdate -NotCategory 'Upgrades', 'Feature Packs' -ErrorAction Stop)
}
catch {
    Write-Warn ("Windows Update query failed: {0}" -f $_.Exception.Message)
    Write-Warn 'Use Settings > Windows Update manually.'
    return
}

if ($pending.Count -eq 0) {
    Write-Ok 'no pending security or quality updates'
    return
}

Write-Log ("{0} update(s) pending; installing without feature upgrades or automatic reboot" -f $pending.Count)
$results = @()
try {
    $results = @(Install-WindowsUpdate -NotCategory 'Upgrades', 'Feature Packs' -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Stop)
}
catch {
    Write-Warn ("update install failed: {0}" -f $_.Exception.Message)
    Write-Warn 'Open Settings > Update & Security > Windows Update and read the error code.'
    Write-Warn 'Details: .\scripts\Diagnose-WindowsUpdate.ps1'
    Write-Fail 'Windows Update install failed. Use -SkipUpdates to provision the rest.'
}

$failedUpdates = @($results | Where-Object { $_.PSObject.Properties['Result'] -and $_.Result -eq 'Failed' })
if ($failedUpdates.Count -gt 0) {
    Write-Fail ("{0} update(s) failed. Run: .\scripts\Diagnose-WindowsUpdate.ps1" -f $failedUpdates.Count)
}

if (Test-RebootPending) {
    Write-Fail 'Update installed and a restart is pending. Restart, then run: .\bootstrap.ps1 -From 15-updates'
}

$remaining = @()
$recheckOk = $true
try { $remaining = @(Get-WindowsUpdate -NotCategory 'Upgrades', 'Feature Packs' -ErrorAction Stop) }
catch { $recheckOk = $false; Write-Warn ("could not re-check pending updates: {0}" -f $_.Exception.Message) }
if (-not $recheckOk) {
    Write-Warn 'Update state is unknown. Check Settings > Windows Update before assuming this step is done.'
}
elseif ($remaining.Count -gt 0) {
    Write-Warn ("{0} update(s) still pending. Restart and re-run, or read the error code in Settings." -f $remaining.Count)
}
else {
    Write-Ok 'updates installed and no update is pending'
}

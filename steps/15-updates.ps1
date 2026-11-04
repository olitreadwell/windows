# Windows Update. Installs pending updates but never reboots automatically.
Set-StrictMode -Version 2.0

if (-not (Test-IsAdmin)) {
    Write-Warn 'Windows Update needs admin. Run from an elevated shell.'
    return
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
        return
    }
}

Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
if (-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)) {
    Write-Warn 'Get-WindowsUpdate is unavailable. Use Settings > Windows Update manually.'
    return
}

$pending = @(Get-WindowsUpdate -ErrorAction SilentlyContinue)
if ($pending.Count -eq 0) {
    Write-Ok 'no pending Windows updates'
    return
}

Write-Log ("{0} update(s) pending; installing without automatic reboot" -f $pending.Count)
Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Continue
Write-Warn 'Some updates need a restart. Restart before running the next step.'
Write-Log 'resume: .\bootstrap.ps1 -From 20-winget'

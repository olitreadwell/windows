# Windows settings a developer wants on a fresh install. Each value is read
# first, so a second run changes nothing. UAC stays on.
Set-StrictMode -Version 2.0

if (-not (Test-IsAdmin)) {
    Write-Warn 'Settings need admin. Run from an elevated shell.'
    return
}

# Long paths. Deep node_modules and git checkouts fail without this.
$changed = $false
$explorerChanged = $false
$fileSystem = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
if ((Get-RegistryValue -Path $fileSystem -Name LongPathsEnabled) -ne 1) {
    Set-ItemProperty -Path $fileSystem -Name LongPathsEnabled -Value 1 -Type DWord
    $changed = $true
    Write-Ok 'long paths enabled'
}
else {
    Write-Ok 'long paths already enabled'
}

# Developer Mode. Lets the current user create symlinks without elevation,
# which is what the dotfile linking falls back to when hard links fail.
$devMode = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $devMode)) { New-Item -Path $devMode -Force | Out-Null }
if ((Get-RegistryValue -Path $devMode -Name AllowDevelopmentWithoutDevLicense) -ne 1) {
    Set-ItemProperty -Path $devMode -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
    $changed = $true
    Write-Ok 'developer mode enabled'
}
else {
    Write-Ok 'developer mode already enabled'
}

# Explorer: show file extensions and the full path in the title bar.
$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
if (-not (Test-Path $advanced)) { New-Item -Path $advanced -Force | Out-Null }
if ((Get-RegistryValue -Path $advanced -Name HideFileExt) -ne 0) {
    Set-ItemProperty -Path $advanced -Name HideFileExt -Value 0 -Type DWord
    $changed = $true
    $explorerChanged = $true
    Write-Ok 'file extensions shown'
}
else {
    Write-Ok 'file extensions already shown'
}
if ((Get-RegistryValue -Path $advanced -Name FullPath) -ne 1) {
    Set-ItemProperty -Path $advanced -Name FullPath -Value 1 -Type DWord
    $changed = $true
    $explorerChanged = $true
    Write-Ok 'full path shown in Explorer title'
}
else {
    Write-Ok 'full path already shown in Explorer title'
}

# Explorer opens This PC instead of Quick Access.
if ((Get-RegistryValue -Path $advanced -Name LaunchTo) -ne 1) {
    Set-ItemProperty -Path $advanced -Name LaunchTo -Value 1 -Type DWord
    $changed = $true
    $explorerChanged = $true
    Write-Ok 'Explorer opens This PC'
}
else {
    Write-Ok 'Explorer already opens This PC'
}

# Clipboard history for Win+V.
$clipboard = 'HKCU:\Software\Microsoft\Clipboard'
if (-not (Test-Path $clipboard)) { New-Item -Path $clipboard -Force | Out-Null }
if ((Get-RegistryValue -Path $clipboard -Name EnableClipboardHistory) -ne 1) {
    Set-ItemProperty -Path $clipboard -Name EnableClipboardHistory -Value 1 -Type DWord
    $changed = $true
    Write-Ok 'clipboard history enabled (Win+V)'
}
else {
    Write-Ok 'clipboard history already enabled'
}

# Turn off the tips and suggested-content popups.
$delivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (Test-Path $delivery) {
    if ((Get-RegistryValue -Path $delivery -Name SoftLandingEnabled) -ne 0) {
        Set-ItemProperty -Path $delivery -Name SoftLandingEnabled -Value 0 -Type DWord
        $changed = $true
        Write-Ok 'Windows tips and suggestions turned off'
    }
    else {
        Write-Ok 'Windows tips already off'
    }
}

# The current user may run local scripts. Downloaded scripts still need a
# signature, so RemoteSigned is the usual developer setting.
try {
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -in @('Restricted', 'Undefined', 'Default')) {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Write-Ok 'execution policy set to RemoteSigned for the current user'
    }
    elseif ($policy -eq 'AllSigned') {
        Write-Warn 'execution policy stays AllSigned; local unsigned scripts will be blocked'
    }
    else {
        Write-Ok ("execution policy already permissive: {0}" -f $policy)
    }
}
catch {
    Write-Warn ("execution policy not changed: {0}" -f $_.Exception.Message)
}

# Defender: block potentially unwanted applications, not just known malware.
try {
    $preference = Get-MpPreference -ErrorAction Stop
    if ($preference.PUAProtection -ne 1) {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Write-Ok 'Defender PUA protection enabled'
    }
    else {
        Write-Ok 'Defender PUA protection already enabled'
    }
}
catch {
    Write-Warn ("Defender preference not changed: {0}" -f $_.Exception.Message)
}

# Privacy defaults. Registry only, no apps removed, all reversible.
$privacy = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSyncProviderNotifications'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCortana'; Value = 0 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
)
$privacyChanged = 0
foreach ($item in $privacy) {
    if (-not (Test-Path $item.Path)) { New-Item -Path $item.Path -Force | Out-Null }
    if ((Get-RegistryValue -Path $item.Path -Name $item.Name) -ne $item.Value) {
        Set-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -Type DWord -ErrorAction SilentlyContinue
        if ((Get-RegistryValue -Path $item.Path -Name $item.Name) -eq $item.Value) { $privacyChanged++ }
    }
}
Write-Ok ("privacy settings: {0} changed, {1} already set" -f $privacyChanged, ($privacy.Count - $privacyChanged))

# Reverse the scroll direction, the same way macOS feels. Windows 10 has no
# Settings toggle for this, so it goes on each HID mouse device. Unplug and
# replug the mouse, or restart, if the change does not apply immediately.
$mouseDevices = @(Get-PnpDevice -Class Mouse -Status OK -ErrorAction SilentlyContinue)
$reversed = 0
foreach ($device in $mouseDevices) {
    $devicePath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($device.InstanceId)\Device Parameters"
    if (-not (Test-Path $devicePath)) { continue }
    if ((Get-RegistryValue -Path $devicePath -Name FlipFlopWheel) -ne 1) {
        Set-ItemProperty -Path $devicePath -Name FlipFlopWheel -Value 1 -Type DWord -ErrorAction SilentlyContinue
        if ((Get-RegistryValue -Path $devicePath -Name FlipFlopWheel) -eq 1) { $reversed++ }
    }
}
if ($reversed -gt 0) {
    Write-Ok ("reversed scroll direction on {0} pointing device(s); replug or restart" -f $reversed)
}
else {
    Write-Ok 'scroll direction already reversed, or no HID device accepted the value'
}

# Restart Explorer so the Explorer changes appear without a sign-out.
$explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue
if ($explorerChanged -and $explorer) {
    Write-Log 'restarting Explorer to apply the folder settings'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

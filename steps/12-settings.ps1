# Windows settings a developer wants on a fresh install. Each value is read
# first, so a second run changes nothing. UAC stays on.
Set-StrictMode -Version 2.0

if (-not (Test-IsAdmin)) {
    Write-Warn 'Settings need admin. Run from an elevated shell.'
    return
}

# Long paths. Deep node_modules and git checkouts fail without this.
$fileSystem = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
if ((Get-RegistryValue -Path $fileSystem -Name LongPathsEnabled) -ne 1) {
    Set-ItemProperty -Path $fileSystem -Name LongPathsEnabled -Value 1 -Type DWord
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
    Write-Ok 'file extensions shown'
}
else {
    Write-Ok 'file extensions already shown'
}
if ((Get-RegistryValue -Path $advanced -Name FullPath) -ne 1) {
    Set-ItemProperty -Path $advanced -Name FullPath -Value 1 -Type DWord
    Write-Ok 'full path shown in Explorer title'
}
else {
    Write-Ok 'full path already shown in Explorer title'
}

# Explorer opens This PC instead of Quick Access.
if ((Get-RegistryValue -Path $advanced -Name LaunchTo) -ne 1) {
    Set-ItemProperty -Path $advanced -Name LaunchTo -Value 1 -Type DWord
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
        Write-Ok 'Windows tips and suggestions turned off'
    }
    else {
        Write-Ok 'Windows tips already off'
    }
}

# Restart Explorer so the Explorer changes appear without a sign-out.
$explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue
if ($explorer) {
    Write-Log 'restarting Explorer to apply the folder settings'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

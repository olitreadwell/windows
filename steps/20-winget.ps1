# Make sure winget exists. Windows 10 1809 or newer is required.
Set-StrictMode -Version 2.0

$info = Get-MachineInfo

if (Test-CommandExists 'winget') {
    Write-Ok ("winget present: {0}" -f ((& winget --version) -join ' '))
}
else {
    if ($info.BuildNumber -lt 17763) {
        Write-Fail ("winget needs Windows 10 1809 or newer. This machine is build {0}. Update Windows first." -f $info.BuildNumber)
    }

    Write-Log 'winget missing; installing App Installer'
    $bundle = Join-Path $env:TEMP 'Microsoft.DesktopAppInstaller.msixbundle'
    try {
        Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing -ErrorAction Stop
        Add-AppxPackage -Path $bundle -ErrorAction Stop
        Update-SessionPath
        Write-Ok 'winget installed'
    }
    catch {
        Write-Warn ("winget install failed: {0}" -f $_.Exception.Message)
        Write-Warn 'Install App Installer from the Microsoft Store, or from:'
        Write-Warn 'https://github.com/microsoft/winget-cli/releases'
        Write-Fail 'winget is required for the remaining steps'
    }
}

& winget source update --accept-source-agreements 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warn 'winget source update failed; continuing with the cached source' }

& winget list --accept-source-agreements 2>$null | Out-Null
Write-Ok 'winget source agreements accepted'

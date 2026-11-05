# Opt-in WSL2. Two Windows features, then a reboot before any distribution
# can install. Only runs with -Wsl.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$enabled = $false
$flag = Get-Variable -Name OliInstallWsl -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'WSL skipped. Use -Wsl to enable it.'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'WSL setup needs admin. Run from an elevated shell.'
    return
}

$features = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
$changed = $false
foreach ($name in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue).State
    if ($state -eq 'Enabled') {
        Write-Ok ("feature already enabled: {0}" -f $name)
        continue
    }
    & dism.exe /Online /Enable-Feature /FeatureName:$name /All /NoRestart | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok ("feature enabled: {0}" -f $name); $changed = $true }
    else { Write-Warn ("feature failed: {0} (exit {1})" -f $name, $LASTEXITCODE) }
}

if ($changed -or (Test-RebootPending)) {
    Write-Warn 'Restart Windows, then run: .\bootstrap.ps1 -Only 21-wsl'
    return
}

if (-not (Test-CommandWorks -Name 'wsl' -Arguments @('--version'))) {
    Install-WingetPackage -Id 'Microsoft.WSL' | Out-Null
}

try {
    & wsl.exe --update 2>&1 | Out-Null
    & wsl.exe --install -d Ubuntu --no-launch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Ubuntu installed for WSL. Launch it once to set a Linux username.' }
    else { Write-Warn ("Ubuntu install exited {0}. Run: wsl --install -d Ubuntu" -f $LASTEXITCODE) }
}
catch {
    Write-Warn ("WSL distribution install failed: {0}" -f $_.Exception.Message)
}

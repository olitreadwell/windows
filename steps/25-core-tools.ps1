# Core CLI tools. All installs are idempotent.
Set-StrictMode -Version 2.0

$packages = Get-PackageSection -Path (Join-Path $global:OliRepoRoot 'config/packages.txt') -Section 'core'
if ($packages.Count -eq 0) {
    Write-Fail 'config/packages.txt has no [core] entries'
}

if (-not (Test-WingetAvailable)) {
    Write-Fail 'winget is not usable. Run: .\bootstrap.ps1 -Only 20-winget'
}

$failed = @()
foreach ($id in $packages) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}

Update-SessionPath
if ($failed.Count -gt 0) {
    Write-Fail ("core packages failed: {0} | fix, then resume: .\bootstrap.ps1 -From 25-core-tools" -f ($failed -join ', '))
}
else {
    Write-Ok 'core CLI tools installed'
}

# Prefer the real install over the WindowsApps alias stub. The stub fails
# with "no applicable licenses" when only the MSI is installed.
$pwshPath = Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
if (-not (Test-Path $pwshPath)) {
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCommand) { $pwshPath = $pwshCommand.Source }
}
if ($pwshPath -and (Test-Path $pwshPath)) {
    try {
        $pwshVersion = & $pwshPath -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        if ($LASTEXITCODE -eq 0 -and $pwshVersion) {
            Write-Ok ("PowerShell 7: {0}" -f ($pwshVersion -join ' '))
        }
        else {
            Write-Warn ("pwsh did not run cleanly: {0}" -f ($pwshVersion -join ' '))
        }
    }
    catch {
        Write-Warn ("pwsh probe failed: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Warn 'pwsh is not installed yet. Open a new terminal and check: pwsh --version'
}

# gsudo caches one elevated session so a burst of admin commands does not
# prompt each time. UAC stays on; the cache expires after 30 minutes.
if (Test-CommandExists 'gsudo') {
    try {
        & gsudo config CacheMode auto | Out-Null
        & gsudo config CacheDuration 00:30:00 | Out-Null
        Write-Ok 'gsudo caches elevation for 30 minutes (UAC stays on)'
    }
    catch {
        Write-Warn ("gsudo config failed: {0}" -f $_.Exception.Message)
    }
}

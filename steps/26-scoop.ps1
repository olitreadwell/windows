# Scoop, the second package manager. winget covers the default install;
# Scoop covers the unix-style CLI packages that winget does not ship.
#
# Scoop refuses a user install from an elevated window, and the bootstrap
# always runs elevated. This step therefore prints the exact command for a
# normal window instead of installing a global copy that needs admin for
# every later package.
Set-StrictMode -Version 2.0

$scoopShim = Join-Path $HOME 'scoop/shims/scoop.cmd'
if ((Test-CommandExists 'scoop') -or (Test-Path $scoopShim)) {
    Write-Ok 'scoop already installed'
    return
}

if (Test-IsAdmin) {
    Write-Warn 'Scoop is not installed: it refuses a user install from an elevated window.'
    Write-Warn 'Open a normal PowerShell window after this run and paste:'
    Write-Warn '  Set-ExecutionPolicy -Scope Process Bypass -Force; irm get.scoop.sh | iex'
    Write-Warn '  scoop bucket add extras'
    return
}

$installer = Join-Path $env:TEMP 'scoop-install.ps1'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri 'https://get.scoop.sh' -OutFile $installer -UseBasicParsing -ErrorAction Stop
    $hash = (Get-FileHash -Path $installer -Algorithm SHA256).Hash
    Write-Log ("scoop installer sha256: {0}" -f $hash)
    & $installer
    if ($LASTEXITCODE -ne 0) { throw "installer exited $LASTEXITCODE" }
}
catch {
    Write-Warn ("scoop install failed: {0}" -f $_.Exception.Message)
    Write-Warn 'Install it by hand: https://scoop.sh'
    return
}

if (Test-Path $scoopShim) {
    $env:Path = (Join-Path $HOME 'scoop/shims') + ';' + $env:Path
    Write-Ok 'scoop installed'
    & $scoopShim bucket add extras 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warn 'scoop bucket add extras failed' }
    else { Write-Ok 'scoop extras bucket added' }
}
else {
    Write-Warn 'scoop installer ran but the shim is missing. Open a new terminal and run: scoop --version'
}

# Runtimes through mise. Fallbacks are installed separately as CLI tools.
Set-StrictMode -Version 2.0

if (-not (Test-CommandExists 'mise')) {
    Write-Warn 'mise is missing. Re-run 25-core-tools, or install it with: winget install jdx.mise'
    return
}

$configPath = Join-Path $HOME '.config/mise/config.toml'
if (-not (Test-Path $configPath)) {
    Write-Warn ("mise config missing: {0}" -f $configPath)
    return
}

Push-Location $HOME
try {
    & mise trust $configPath 2>$null | Out-Null
    & mise install
    $miseExit = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($miseExit -ne 0) {
    Write-Warn 'mise install failed on this machine. Installing the fallbacks.'
    Install-WingetPackage -Id 'Schniz.fnm' | Out-Null
    Install-WingetPackage -Id 'Oven-sh.Bun' | Out-Null
    Write-Warn 'Run: fnm install --lts'
    Write-Warn 'Then check: bun --version; uv --version'
    return
}

Write-Ok 'mise runtimes installed'
& mise ls

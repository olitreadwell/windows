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

& mise trust $configPath 2>$null | Out-Null
& mise install
if ($LASTEXITCODE -ne 0) {
    Write-Warn 'mise install failed on this machine.'
    Write-Warn 'Fallback: uv python install 3.14; fnm install --lts; bun --version'
    return
}

Write-Ok 'mise runtimes installed'
& mise ls

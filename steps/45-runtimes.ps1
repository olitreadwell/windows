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
    & mise trust $configPath 2>&1 | Out-Null
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

    # Report the tools from mise.toml that still have no command, so the gap
    # is named instead of discovered later by a failing build.
    $declared = @()
    $inTools = $false
    foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\[(.+)\]$') { $inTools = ($Matches[1] -eq 'tools'); continue }
        if ($inTools -and $line -match '^\s*([A-Za-z0-9_-]+)\s*=') { $declared += $Matches[1] }
    }
    $unavailable = @($declared | Where-Object { -not (Test-CommandWorks -Name $_) })
    if ($unavailable.Count -gt 0) {
        Write-Warn ("runtimes still missing: {0}" -f ($unavailable -join ', '))
        Write-Warn 'Install them with winget before relying on this machine for that language.'
    }
    return
}

Write-Ok 'mise runtimes installed'
& mise ls

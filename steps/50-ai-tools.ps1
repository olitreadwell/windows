# Codex CLI, Claude Code, and their first-run auth.
Set-StrictMode -Version 2.0

$packages = Get-PackageSection -Path (Join-Path $global:OliRepoRoot 'config/packages.txt') -Section 'ai'
foreach ($id in $packages) {
    Install-WingetPackage -Id $id | Out-Null
}

Update-SessionPath

if (Test-CommandExists 'codex') {
    Write-Ok ("codex present: {0}" -f ((& codex --version) -join ' '))
    $authFile = Join-Path $HOME '.codex/auth.json'
    if (Test-Path $authFile) {
        Write-Ok 'codex is authenticated'
    }
    elseif ($global:OliAssumeYes) {
        Write-Warn 'codex is not authenticated. Run: codex login'
    }
    else {
        & codex login
    }
}
else {
    Write-Warn 'codex is not on PATH yet. Open a new terminal and check: codex --version'
}

if (Test-CommandExists 'claude') {
    Write-Ok ("claude present: {0}" -f ((& claude --version) -join ' '))
    Write-Warn 'If Claude Code is not signed in, run: claude auth login'
}
else {
    Write-Warn 'claude is not on PATH yet. Open a new terminal and check: claude --version'
}

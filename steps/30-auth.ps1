# GitHub CLI auth. Interactive by default; -Yes leaves it for the human.
Set-StrictMode -Version 2.0

if (-not (Test-CommandExists 'gh')) {
    Write-Warn 'gh is not installed; skipping GitHub auth'
    return
}

& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok 'gh already authenticated'
    & gh auth setup-git 2>$null | Out-Null
    return
}

if ($global:OliAssumeYes) {
    Write-Warn 'gh is not authenticated. Run: gh auth login --web'
    return
}

& gh auth login --web --hostname github.com
if ($LASTEXITCODE -ne 0) {
    Write-Warn 'gh auth failed; private repo clones will not work until it is fixed'
    return
}

& gh auth setup-git 2>$null | Out-Null
Write-Ok 'gh authenticated and git credential helper configured'

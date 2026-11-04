# Final check: what works now, and what still needs a human.
Set-StrictMode -Version 2.0

$required = @('winget', 'git', 'gh', 'op', 'pwsh', 'mise')
$missing = @()
foreach ($tool in $required) {
    if (Test-CommandExists $tool) {
        Write-Ok ("found: {0}" -f $tool)
    }
    else {
        Write-Warn ("missing: {0}" -f $tool)
        $missing += $tool
    }
}

if (Test-CommandExists 'git') {
    $name = & git config --global user.name 2>$null
    $email = & git config --global user.email 2>$null
    if ($name -and $email) {
        Write-Ok ("git identity: {0} <{1}>" -f $name, $email)
    }
    else {
        Write-Warn 'git identity is not set'
    }
}

$skill = Join-Path $HOME '.claude/skills/caveman'
if (Test-Path $skill) {
    Write-Ok 'ai-harness skills linked into .claude/skills'
}
else {
    Write-Warn 'ai-harness skills are not linked into .claude/skills'
}

$info = Get-MachineInfo
$stateDir = Get-StateDir
$info | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $stateDir 'system-info.json') -Encoding UTF8
Write-Ok ("machine snapshot: {0}" -f (Join-Path $stateDir 'system-info.json'))

Write-Host ''
Write-Host 'Next actions for a human:' -ForegroundColor Cyan
Write-Host '  1. Restart Windows if updates asked for it.'
Write-Host '  2. Sign in to 1Password and enable Developer > SSH agent.'
Write-Host '  3. Run: gh auth status; codex login; claude auth login'
Write-Host '  4. Open a new PowerShell 7 window and run: starship --version; mise ls'
Write-Host ''
if ($missing.Count -gt 0) {
    Write-Fail ("verification missing: {0}" -f ($missing -join ', '))
}
Write-Ok 'verification passed'

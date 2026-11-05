# Final check: what works now, and what still needs a human.
Set-StrictMode -Version 2.0

$required = @('winget', 'git', 'gh', 'op', 'pwsh', 'mise', 'codex', 'claude')
$missing = @()
foreach ($tool in $required) {
    if (Test-CommandWorks -Name $tool) {
        Write-Ok ("found: {0}" -f $tool)
    }
    else {
        Write-Warn ("missing: {0}" -f $tool)
        $missing += $tool
    }
}

if (Test-CommandWorks -Name 'gh') {
    & gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warn 'gh is installed but not authenticated. Run: gh auth login --web' }
}
if (Test-CommandWorks -Name 'op') {
    & op account list 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warn '1Password CLI is installed but not signed in' }
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
    $missing += 'ai-harness skills'
}

$info = Get-MachineInfo
$stateDir = Get-StateDir
$info | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $stateDir 'system-info.json') -Encoding UTF8
Write-Ok ("machine snapshot: {0}" -f (Join-Path $stateDir 'system-info.json'))

$fontKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontNames = @()
$fontProperties = Get-ItemProperty -Path $fontKey -ErrorAction SilentlyContinue
if ($fontProperties) { $fontNames = @($fontProperties.PSObject.Properties.Name) }
if ($fontNames -match 'JetBrainsMono Nerd Font') {
    Write-Ok 'JetBrainsMono Nerd Font installed'
}
else {
    Write-Warn 'Nerd Font missing; eza icons and the Starship prompt will show boxes'
}
Write-Host '  Set Windows Terminal > Profiles > Defaults > Appearance > Font face to JetBrainsMono Nerd Font.'

foreach ($module in @('PSFzf', 'Terminal-Icons')) {
    if (Get-Module -ListAvailable -Name $module) { Write-Ok ("module: {0}" -f $module) }
    else { Write-Warn ("module missing: {0}" -f $module) }
}

Write-Host ''
Write-Host 'Next actions for a human:' -ForegroundColor Cyan
Write-Host '  1. Restart Windows if updates asked for it.'
Write-Host '  2. Sign in to 1Password and enable Developer > SSH agent.'
Write-Host '  3. Run: gh auth status; claude auth login'
Write-Host '  4. Set OLLAMA_CLOUD_MAX_API_KEY for Codex if it is missing.'
Write-Host '  5. Open a new PowerShell 7 window and run: starship --version; mise ls'
Write-Host ''
if ($missing.Count -gt 0) {
    Write-Fail ("verification missing: {0}" -f ($missing -join ', '))
}
Write-Ok 'verification passed'

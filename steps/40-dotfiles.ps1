# Clone dotfiles and ai-harness, then wire Windows-specific configs.
Set-StrictMode -Version 2.0
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'Never'

function Update-GitRepo {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (Test-Path (Join-Path $Destination '.git')) {
        & git -c credential.interactive=false -C $Destination pull --ff-only origin main 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn "pull failed: $Repo" }
        else { Write-Ok "updated: $Repo" }
        return
    }

    if (Test-Path $Destination) {
        $backup = "$Destination.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item -LiteralPath $Destination -Destination $backup
        Write-Warn "moved non-git directory aside: $Destination -> $backup"
    }

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $useGh = (Test-CommandExists 'gh')
    if ($useGh) {
        & gh auth status 2>$null | Out-Null
        $useGh = ($LASTEXITCODE -eq 0)
    }

    if (-not $useGh -and $global:OliAssumeYes) {
        Write-Warn ("private repo needs gh auth; skipping: {0}. Run: gh auth login" -f $Repo)
        return
    }

    if ($useGh) { & gh repo clone $Repo $Destination }
    else { & git -c credential.interactive=false clone ("https://github.com/{0}.git" -f $Repo) $Destination }

    if ($LASTEXITCODE -ne 0) { Write-Fail "clone failed: $Repo" }
    Write-Ok "cloned: $Repo"
}

$dotfiles = Join-Path $HOME 'dotfiles'
$harness = Join-Path $HOME '.agents'
Update-GitRepo -Repo 'olitreadwell/dotfiles' -Destination $dotfiles
Update-GitRepo -Repo 'olitreadwell/ai-harness' -Destination $harness

Install-AgentHarness -HarnessDir $harness

Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'config/gitconfig.txt') -Destination (Join-Path $HOME '.gitconfig') -CopyOnly | Out-Null
Set-ManagedFile -Source (Join-Path $dotfiles 'dot_gitignore_global') -Destination (Join-Path $HOME '.gitignore_global') | Out-Null
Set-ManagedFile -Source (Join-Path $dotfiles 'gitmessage') -Destination (Join-Path $HOME '.gitmessage') | Out-Null
Set-ManagedFile -Source (Join-Path $dotfiles 'dot_config/gh/config.yml') -Destination (Join-Path $HOME '.config/gh/config.yml') -CopyOnly | Out-Null

$starshipSource = Join-Path $global:OliRepoRoot 'config/starship.toml'
Set-ManagedFile -Source $starshipSource -Destination (Join-Path $HOME '.config/starship.toml') | Out-Null

Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'config/mise.toml') -Destination (Join-Path $HOME '.config/mise/config.toml') | Out-Null

$binDir = Join-Path $HOME 'bin'
Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'scripts/Update-All.ps1') -Destination (Join-Path $binDir 'update.ps1') -CopyOnly | Out-Null
Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'scripts/Diagnose-WindowsUpdate.ps1') -Destination (Join-Path $binDir 'diagnose-update.ps1') -CopyOnly | Out-Null

$hooksSource = Join-Path $dotfiles 'git_hooks'
if (Test-Path $hooksSource) {
    Set-ManagedDirectory -Source $hooksSource -Destination (Join-Path $HOME '.config/git/hooks') | Out-Null
}

$codexDir = Join-Path $HOME '.codex'
if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Path $codexDir -Force | Out-Null }
$codexConfig = Join-Path $codexDir 'config.toml'
if (-not (Test-Path $codexConfig)) {
    Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'config/codex/config.toml') -Destination $codexConfig -CopyOnly | Out-Null
}
else {
    Write-Log 'codex config already exists; left untouched'
}
Set-ManagedFile -Source (Join-Path $global:OliRepoRoot 'config/codex/rules/default.rules') -Destination (Join-Path $codexDir 'rules/default.rules') | Out-Null

$catalog = Join-Path $codexDir 'model-catalog.json'
if (-not (Test-Path $catalog)) {
    try {
        Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/olitreadwell/laptop/main/config/codex-model-catalog.json' -OutFile $catalog -UseBasicParsing -ErrorAction Stop
        Write-Ok 'codex model catalog downloaded'
    }
    catch { Write-Warn ("model catalog download failed: {0}" -f $_.Exception.Message) }
}

$profileSource = Join-Path $global:OliRepoRoot 'config/profile/Microsoft.PowerShell_profile.ps1'
$documents = [Environment]::GetFolderPath('MyDocuments')
if (-not $documents) { $documents = Join-Path $HOME 'Documents' }
$profilePaths = @(
    (Join-Path $documents 'WindowsPowerShell/Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documents 'PowerShell/Microsoft.PowerShell_profile.ps1')
)
foreach ($path in $profilePaths) {
    Set-ManagedFile -Source $profileSource -Destination $path | Out-Null
}

$syncScript = Join-Path $global:OliRepoRoot 'scripts/Sync-DefaultSkills.ps1'
$skillsDir = Join-Path $harness 'skills'
if ((Test-Path $syncScript) -and (Test-Path $codexConfig) -and (Test-Path $skillsDir)) {
    & $syncScript -ConfigPath $codexConfig
}
else {
    Write-Warn 'ai-harness skills are missing; skipped the default-skills sync'
}

& git config --global user.name 'olitreadwell'
if ($LASTEXITCODE -ne 0) { Write-Warn 'git config user.name failed' }
& git config --global user.email 'oliver.treadwell@gmail.com'
if ($LASTEXITCODE -ne 0) { Write-Warn 'git config user.email failed' }
& git config --global credential.helper manager
if ($LASTEXITCODE -ne 0) { Write-Warn 'git config credential.helper failed' }
& git config --global core.longpaths true
if ($LASTEXITCODE -ne 0) { Write-Warn 'git config core.longpaths failed' }
Write-Ok 'git identity and credential helper set'

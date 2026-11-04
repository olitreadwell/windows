# Windows port of ai-harness install.sh. Skills are directories, so junctions
# replace symlinks. Files use hard links, which need no admin rights.
Set-StrictMode -Version 2.0

function Install-AgentHarness {
    param([Parameter(Mandatory = $true)][string]$HarnessDir)

    $skillsDir = Join-Path $HarnessDir 'skills'
    if (-not (Test-Path $skillsDir)) {
        Write-Warn "ai-harness skills dir missing: $skillsDir"
        return
    }

    foreach ($requiredDir in @('.codex', '.claude')) {
        $path = Join-Path $HOME $requiredDir
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }

    $toolSkillDirs = @(
        '.claude\skills',
        '.codex\skills',
        '.config\opencode\skills',
        '.config\crush\skills',
        '.continue\skills',
        '.aider-desk\skills'
    )

    foreach ($relative in $toolSkillDirs) {
        $toolSkillsDir = Join-Path $HOME $relative
        $toolDir = Split-Path -Parent $toolSkillsDir
        if (-not (Test-Path $toolDir)) { continue }

        if (-not (Test-Path $toolSkillsDir)) {
            New-Item -ItemType Directory -Path $toolSkillsDir -Force | Out-Null
        }

        foreach ($skill in Get-ChildItem -Path $skillsDir -Directory) {
            $destination = Join-Path $toolSkillsDir $skill.Name
            Set-ManagedDirectory -Source $skill.FullName -Destination $destination | Out-Null
        }
    }

    $codexDir = Join-Path $HOME '.codex'
    if (Test-Path $codexDir) {
        Set-ManagedFile -Source (Join-Path $HarnessDir 'AGENTS.md') -Destination (Join-Path $codexDir 'AGENTS.md') | Out-Null

        $sourceAgents = Join-Path $HarnessDir 'agents'
        if (Test-Path $sourceAgents) {
            $destinationAgents = Join-Path $codexDir 'agents'
            if (-not (Test-Path $destinationAgents)) {
                New-Item -ItemType Directory -Path $destinationAgents -Force | Out-Null
            }
            foreach ($agent in Get-ChildItem -Path $sourceAgents -Filter '*.toml') {
                Set-ManagedFile -Source $agent.FullName -Destination (Join-Path $destinationAgents $agent.Name) | Out-Null
            }
        }
    }

    $claudeDir = Join-Path $HOME '.claude'
    if (Test-Path $claudeDir) {
        Set-ManagedFile -Source (Join-Path $HarnessDir 'AGENTS.md') -Destination (Join-Path $claudeDir 'CLAUDE.md') | Out-Null
    }
}

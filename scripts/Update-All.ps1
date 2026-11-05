#Requires -Version 5.1
<#
.SYNOPSIS
Update winget packages, mise runtimes and agent CLI extensions in one pass.

.DESCRIPTION
Runs the same update commands every time, so there is one command to
remember. It never reboots and never changes Windows Update settings.

.EXAMPLE
.\scripts\Update-All.ps1 -DryRun

.EXAMPLE
.\scripts\Update-All.ps1
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
}

function Test-Tool {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Tool 'winget')) {
    Write-Warning 'winget is missing. Run: .\bootstrap.ps1 -Only 20-winget'
    exit 2
}

Write-Section 'winget upgrades'
if ($DryRun) {
    & winget upgrade --include-unknown --accept-source-agreements --disable-interactivity
}
else {
    & winget upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        Write-Warning ("winget upgrade returned 0x{0:X8}. Some packages may already be current." -f $LASTEXITCODE)
    }
}

Write-Section 'mise runtimes'
if (Test-Tool 'mise') {
    if ($DryRun) { & mise outdated }
    else {
        & mise upgrade
        if ($LASTEXITCODE -ne 0) { Write-Warning 'mise upgrade reported a failure' }
    }
}
else {
    Write-Warning 'mise is missing. Run: .\bootstrap.ps1 -Only 25-core-tools'
}

Write-Section 'gh extensions'
if (Test-Tool 'gh') {
    if ($DryRun) { & gh extension list }
    else { & gh extension upgrade --all 2>$null }
}

Write-Section 'agent CLIs'
foreach ($tool in @('codex', 'claude')) {
    if (Test-Tool $tool) {
        & $tool --version
    }
    else {
        Write-Warning ("{0} is not on PATH" -f $tool)
    }
}

if (Test-Tool 'codex') {
    $completionPath = Join-Path $HOME '.codex/completions.ps1'
    $completionDir = Split-Path -Parent $completionPath
    if (-not (Test-Path $completionDir)) { New-Item -ItemType Directory -Path $completionDir -Force | Out-Null }
    $completion = & codex completion powershell
    if ($LASTEXITCODE -eq 0 -and $completion) {
        $completion | Set-Content -Path $completionPath -Encoding UTF8
        Write-Host ("  refreshed: {0}" -f $completionPath)
    }
}

Write-Section 'PowerShell modules'
foreach ($module in @('PSFzf', 'Terminal-Icons')) {
    if (Get-Module -ListAvailable -Name $module) {
        Update-Module -Name $module -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($DryRun) { Write-Host 'Dry run. Nothing was changed.' -ForegroundColor Yellow }
else { Write-Host 'Updates finished. Open a new terminal if a CLI version looks stale.' -ForegroundColor Green }

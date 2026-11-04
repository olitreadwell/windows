# Gate for the windows repo. Runs on Windows; CI uses a windows-latest runner.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$script:failures = 0

function Add-Failure {
    param([string]$Message)
    Write-Host ("FAIL: {0}" -f $Message) -ForegroundColor Red
    $script:failures++
}

$scripts = @(Get-ChildItem -Path $repoRoot -Recurse -Filter '*.ps1' -File)
foreach ($script in $scripts) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Add-Failure ("syntax {0}: {1}" -f $script.FullName, $errors[0].Message)
    }
}
Write-Host ("parsed {0} PowerShell files" -f $scripts.Count)

$required = @(
    'bootstrap.ps1',
    'PROMPT.md',
    'README.md',
    'AGENTS.md',
    'CODING_STANDARDS.md',
    'config/packages.txt',
    'config/gitconfig.txt',
    'config/mise.toml',
    'config/codex/config.toml',
    'config/codex/rules/default.rules',
    'config/profile/Microsoft.PowerShell_profile.ps1',
    'core/Install-AgentHarness.ps1',
    'docs/new-machine-runbook.md',
    'knowledge/decisions.md',
    'knowledge/hardware.md',
    'knowledge/windows-10-eol.md',
    'knowledge/migration-map.md',
    'repos.txt'
)
foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $repoRoot $relative))) { Add-Failure "missing file: $relative" }
}

. (Join-Path $repoRoot 'core/Log.ps1')
. (Join-Path $repoRoot 'core/Safe.ps1')
. (Join-Path $repoRoot 'core/Detect.ps1')
. (Join-Path $repoRoot 'core/Plan.ps1')
. (Join-Path $repoRoot 'core/Winget.ps1')
Initialize-Log -RepoRoot $repoRoot

if ($env:OS -eq 'Windows_NT') {
    $info = Get-MachineInfo
    foreach ($key in @('WindowsCaption', 'BuildNumber', 'CpuName', 'RamGb', 'WindowsFamily', 'WindowsSupport')) {
        if ($null -eq $info[$key] -or "$($info[$key])" -eq '') {
            Add-Failure ("detect missing key: {0}" -f $key)
        }
    }
}
else {
    Write-Host 'not Windows: skipping live detection checks'
}

$generations = @{
    'Intel(R) Core(TM) i5-7300U CPU @ 2.60GHz' = 7
    'Intel(R) Core(TM) i5-8350U CPU @ 1.70GHz' = 8
    'Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz' = 8
    'Intel(R) Core(TM) i7-1065G7 CPU' = 10
    'Intel(R) Core(TM) i5-1135G7 CPU' = 11
    'Intel(R) Core(TM) i5-1340P' = 13
}
foreach ($name in $generations.Keys) {
    $actual = Get-CpuGeneration -Name $name
    if ($actual -ne $generations[$name]) {
        Add-Failure ("cpu generation: {0} expected {1} got {2}" -f $name, $generations[$name], $actual)
    }
}

$plan = @(Get-StepPlan -RepoRoot $repoRoot)
if ($plan.Count -eq 0) { Add-Failure 'empty step plan' }
$expectedSteps = @(
    '10-preflight', '15-updates', '20-winget', '25-core-tools', '30-auth',
    '35-1password', '40-dotfiles', '45-runtimes', '50-ai-tools', '60-apps',
    '65-repos', '90-verify'
)
if (($plan -join ',') -ne ($expectedSteps -join ',')) {
    Add-Failure ("step plan mismatch: {0}" -f ($plan -join ', '))
}

$only = @(Get-StepPlan -RepoRoot $repoRoot -Only '40-dotfiles')
if ($only.Count -ne 1 -or $only[0] -ne '40-dotfiles') { Add-Failure '-Only filter failed' }

$from = @(Get-StepPlan -RepoRoot $repoRoot -From '40-dotfiles')
if ($from.Count -eq 0 -or $from[0] -ne '40-dotfiles') { Add-Failure '-From filter failed' }

$core = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'core')
if ($core.Count -eq 0) { Add-Failure 'no [core] packages' }

$ai = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'ai')
if ($ai.Count -eq 0) { Add-Failure 'no [ai] packages' }

$apps = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'apps')
if ($apps.Count -eq 0) { Add-Failure 'no [apps] packages' }

foreach ($id in @($core + $ai + $apps)) {
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$') { Add-Failure ("bad winget id: {0}" -f $id) }
}

$macPath = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.ps1' -File | Where-Object { $_.FullName -ne $PSCommandPath } | Select-String -Pattern '/Users/olitreadwell' -SimpleMatch -ErrorAction SilentlyContinue
if ($macPath) { Add-Failure 'hardcoded macOS home path in a PowerShell file' }

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("windows-test-" + [guid]::NewGuid().ToString())
try {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $sourceFile = Join-Path $tempDir 'source.txt'
    $destinationFile = Join-Path $tempDir 'destination.txt'
    Set-Content -LiteralPath $sourceFile -Value 'one'
    Set-ManagedFile -Source $sourceFile -Destination $destinationFile | Out-Null
    if ((Get-Content -Raw -LiteralPath $destinationFile).Trim() -ne 'one') { Add-Failure 'Set-ManagedFile did not create the destination' }
    Set-Content -LiteralPath $sourceFile -Value 'two'
    if ((Get-Content -Raw -LiteralPath $destinationFile).Trim() -ne 'two') { Add-Failure 'Set-ManagedFile did not keep the link' }

    $sourceDir = Join-Path $tempDir 'source-dir'
    $destinationDir = Join-Path $tempDir 'destination-dir'
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourceDir 'file.txt') -Value 'dir'
    Set-ManagedDirectory -Source $sourceDir -Destination $destinationDir | Out-Null
    if ((Get-Content -Raw -LiteralPath (Join-Path $destinationDir 'file.txt')).Trim() -ne 'dir') {
        Add-Failure 'Set-ManagedDirectory did not expose the source directory'
    }
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:failures -gt 0) {
    Write-Host ("tests failed: {0}" -f $script:failures) -ForegroundColor Red
    exit 1
}
Write-Host 'all checks passed' -ForegroundColor Green

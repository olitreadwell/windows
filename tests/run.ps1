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
    'config/alacritty/alacritty.toml',
    'config/gitconfig.txt',
    'config/mise.toml',
    'config/codex/config.toml',
    'config/codex/rules/default.rules',
    'config/profile/Microsoft.PowerShell_profile.ps1',
    'core/Install-AgentHarness.ps1',
    'docs/new-machine-runbook.md',
    'knowledge/decisions.md',
    'knowledge/hardware.md',
    'knowledge/windows-equivalents.md',
    'knowledge/windows-10-eol.md',
    'knowledge/migration-map.md',
    'scripts/Diagnose-WindowsUpdate.ps1',
    'scripts/Remove-RecordedApps.ps1',
    'scripts/Show-InstalledApps.ps1',
    'scripts/Update-All.ps1',
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

$testStateRoot = Join-Path ([IO.Path]::GetTempPath()) ("oli-windows-state-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $testStateRoot -Force | Out-Null
$originalLocalAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = $testStateRoot
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
    '10-preflight', '12-settings', '13-repair', '14-remote', '15-updates', '16-win10', '17-win11',
    '20-winget', '21-wsl', '25-core-tools', '26-scoop', '27-apps',
    '30-auth', '35-1password', '40-dotfiles', '45-runtimes',
    '47-pwsh-modules', '50-ai-tools', '65-repos', '70-scheduled-update',
    '90-verify'
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
foreach ($id in @('sharkdp.bat', 'eza-community.eza', 'dandavison.delta', 'DEVCOM.JetBrainsMonoNerdFont', 'jqlang.jq', 'Kubernetes.kubectl', 'Microsoft.AzureCLI', 'JesseDuffield.lazygit', 'sxyazi.yazi')) {
    if ($core -notcontains $id) { Add-Failure ("core packages missing: {0}" -f $id) }
}

$ai = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'ai')
if ($ai.Count -eq 0) { Add-Failure 'no [ai] packages' }
foreach ($id in @('OpenAI.Codex', 'Anthropic.ClaudeCode', 'Ollama.Ollama')) {
    if ($ai -notcontains $id) { Add-Failure ("ai packages missing: {0}" -f $id) }
}

$apps = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'apps')
if ($apps.Count -eq 0) { Add-Failure 'no [apps] packages' }
foreach ($id in @('voidtools.Everything', 'ShareX.ShareX', 'Microsoft.PowerToys')) {
    if ($apps -notcontains $id) { Add-Failure ("apps missing: {0}" -f $id) }
}

$optionalApps = @(Get-PackageSection -Path (Join-Path $repoRoot 'config/packages.txt') -Section 'apps-optional')
if ($optionalApps.Count -eq 0) { Add-Failure 'no [apps-optional] packages' }
if ($apps -contains 'TheDocumentFoundation.LibreOffice') { Add-Failure 'LibreOffice belongs in [apps-optional]' }
foreach ($id in @('Zen-Team.Zen-Browser', 'ZedIndustries.Zed', 'Nilesoft.Shell')) {
    if ($apps -notcontains $id) { Add-Failure ("apps missing: {0}" -f $id) }
}

foreach ($id in @($core + $ai + $apps)) {
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$') { Add-Failure ("bad winget id: {0}" -f $id) }
}

$bootstrapText = Get-Content -Path (Join-Path $repoRoot 'bootstrap.ps1') -Raw
if ($bootstrapText -notmatch 'SkipUpdates') { Add-Failure 'bootstrap.ps1 has no -SkipUpdates switch' }
if ($bootstrapText -notmatch 'Parallel') { Add-Failure 'bootstrap.ps1 has no -Parallel switch' }
if ($bootstrapText -notmatch 'ChildRun') { Add-Failure 'bootstrap.ps1 has no -ChildRun switch' }
if ($bootstrapText -notmatch 'OptionalApps') { Add-Failure 'bootstrap.ps1 has no -OptionalApps switch' }

$profileText = Get-Content -Path (Join-Path $repoRoot 'config/profile/Microsoft.PowerShell_profile.ps1') -Raw
foreach ($needle in @('eza', 'Get-Command bat', 'delta', 'fcd', 'function update', 'function logs', 'function apps', 'function doctor', 'function caffeinate', 'function defaultapps', '.codex\completions.ps1', 'PSFzf', 'Terminal-Icons', 'Ctrl+t', 'Ctrl+r')) {
    if ($profileText -notmatch [regex]::Escape($needle)) { Add-Failure ("profile missing: {0}" -f $needle) }
}

$logText = Get-Content -Path (Join-Path $repoRoot 'core/Log.ps1') -Raw
foreach ($needle in @('errors.log', 'Save-RunSummary', 'OliRunId')) {
    if ($logText -notmatch [regex]::Escape($needle)) { Add-Failure ("Log.ps1 missing: {0}" -f $needle) }
}

$settingsText = Get-Content -Path (Join-Path $repoRoot 'steps/12-settings.ps1') -Raw
foreach ($needle in @('LongPathsEnabled', 'AllowDevelopmentWithoutDevLicense', 'EnableClipboardHistory', 'LaunchTo', 'RemoteSigned', 'PUAProtection', 'FlipFlopWheel', 'AllowTelemetry', 'BingSearchEnabled')) {
    if ($settingsText -notmatch [regex]::Escape($needle)) { Add-Failure ("settings step missing: {0}" -f $needle) }
}

$missingValue = Get-RegistryValue -Path 'HKCU:\Software\oli-windows-missing-test-key' -Name Missing
if ($null -ne $missingValue) { Add-Failure 'Get-RegistryValue did not return null for a missing key' }

if (-not (Get-Command Test-CommandWorks -ErrorAction SilentlyContinue)) { Add-Failure 'Test-CommandWorks is missing' }
else {
    if (Test-CommandWorks -Name 'definitely-not-a-real-command-xyz') { Add-Failure 'Test-CommandWorks accepted a missing command' }
}

if (-not (Get-Command Suspend-WindowsUpdate -ErrorAction SilentlyContinue)) { Add-Failure 'Suspend-WindowsUpdate is missing' }

if ($env:OS -eq 'Windows_NT') {
$fakeDir = Join-Path $testStateRoot 'fakebin'
New-Item -ItemType Directory -Path $fakeDir -Force | Out-Null
$shim = @(
    '@echo off',
    'if "%1"=="--version" (echo 1.0.0& exit /b 0)',
    'if "%1"=="list" (',
    '  if exist "%FAKE_WINGET_STATE%" (echo %FAKE_WINGET_ID%& exit /b 0)',
    '  exit /b 1',
    ')',
    'if "%FAKE_WINGET_MODE%"=="fail" exit /b 1',
    'if "%FAKE_WINGET_MODE%"=="hang" ping -n 30 127.0.0.1 >nul',
    'echo installed> "%FAKE_WINGET_STATE%"',
    'exit /b 0'
)
Set-Content -LiteralPath (Join-Path $fakeDir 'winget.cmd') -Value $shim -Encoding Ascii
$savedPath = $env:Path
$env:Path = "$fakeDir;$env:Path"
$stateFile = Join-Path $testStateRoot 'fake-state.txt'
$env:FAKE_WINGET_STATE = $stateFile
$env:FAKE_WINGET_ID = 'Test.NewPackage'
$env:FAKE_WINGET_MODE = 'ok'
Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
if (-not (Install-WingetPackage -Id 'Test.NewPackage')) { Add-Failure 'fake winget: successful install was rejected' }
if (-not (Test-Path $stateFile)) { Add-Failure 'fake winget: install path never ran' }
Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
$env:FAKE_WINGET_MODE = 'fail'
if (Install-WingetPackage -Id 'Test.Failing') { Add-Failure 'fake winget: failure exit was accepted' }
Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
$env:FAKE_WINGET_MODE = 'hang'
$env:OLI_WINGET_TIMEOUT_MINUTES = '0'
$timeoutStart = Get-Date
if (Install-WingetPackage -Id 'Test.Hang') { Add-Failure 'fake winget: timeout was accepted' }
if (((Get-Date) - $timeoutStart).TotalSeconds -gt 30) { Add-Failure 'fake winget: timeout did not return promptly' }
$env:Path = $savedPath
Remove-Item Env:FAKE_WINGET_MODE, Env:FAKE_WINGET_ID, Env:FAKE_WINGET_STATE, Env:OLI_WINGET_TIMEOUT_MINUTES -ErrorAction SilentlyContinue
}

$profilePath = Join-Path $repoRoot 'config/profile/Microsoft.PowerShell_profile.ps1'
$hostPath = (Get-Process -Id $PID).Path
$originalHome = $env:HOME
$originalUserProfile = $env:USERPROFILE
$originalPreference = $ErrorActionPreference
$env:HOME = $testStateRoot
$env:USERPROFILE = $testStateRoot
$ErrorActionPreference = 'Continue'
& $hostPath -NoProfile -Command ". '$profilePath'" 2>&1 | Out-Null
$profileExit = $LASTEXITCODE
$ErrorActionPreference = $originalPreference
$env:HOME = $originalHome
$env:USERPROFILE = $originalUserProfile
if ($profileExit -ne 0) { Add-Failure 'profile failed to load in a child process' }

Write-Log 'ledger test line'
Save-RunSummary -Status 'test' -Started (Get-Date) -Steps @()
if (-not (Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'oli-windows/runs') -Filter '*.json' -ErrorAction SilentlyContinue)) {
    Add-Failure 'Save-RunSummary wrote no run file'
}
try { Write-Fail 'expected test failure' } catch { }
if (-not (Test-Path (Join-Path $env:LOCALAPPDATA 'oli-windows/errors.log'))) {
    Add-Failure 'Write-Fail wrote no errors.log'
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
    Remove-Item -LiteralPath $testStateRoot -Recurse -Force -ErrorAction SilentlyContinue
    $env:LOCALAPPDATA = $originalLocalAppData
}

if ($script:failures -gt 0) {
    Write-Host ("tests failed: {0}" -f $script:failures) -ForegroundColor Red
    exit 1
}
Write-Host 'all checks passed' -ForegroundColor Green

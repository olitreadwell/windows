#Requires -Version 5.1
<#
.SYNOPSIS
Provision a Windows machine from zero to daily driver.

.DESCRIPTION
Runs numbered steps in order. Each step converges from system state, so
re-running is safe. Nothing deletes user data; an overwritten config is
backed up first.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -From 40-dotfiles

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -SkipUpdates

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -Parallel -SkipUpdates
#>
[CmdletBinding()]
param(
    [string]$From,
    [string]$Only,
    [switch]$Parallel,
    [switch]$OptionalApps,
    [switch]$SkipUpdates,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoAdmin
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $repoRoot 'core/Log.ps1')
. (Join-Path $repoRoot 'core/Safe.ps1')
. (Join-Path $repoRoot 'core/Detect.ps1')
. (Join-Path $repoRoot 'core/Plan.ps1')
. (Join-Path $repoRoot 'core/Winget.ps1')
. (Join-Path $repoRoot 'core/Install-AgentHarness.ps1')

Initialize-Log -RepoRoot $repoRoot
$global:OliAssumeYes = [bool]$Yes
$global:OliDryRun = [bool]$DryRun
$global:OliOptionalApps = [bool]$OptionalApps
Write-Log ("run: {0}" -f $global:OliRunId)

# Old Windows 10 builds default to TLS 1.0, which GitHub rejects.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'Never'

$machine = Get-MachineInfo
Write-Host ''
Write-Host 'Windows provisioning' -ForegroundColor Cyan
Write-Host ("  machine : {0} {1}" -f $machine.Manufacturer, $machine.Model)
Write-Host ("  windows : {0} {1} build {2}" -f $machine.WindowsCaption, $machine.DisplayVersion, $machine.BuildNumber)
Write-Host ("  cpu     : {0}" -f $machine.CpuName)
Write-Host ("  memory  : {0} GB, {1} GB free" -f $machine.RamGb, $machine.SystemDriveFreeGb)
Write-Host ("  admin   : {0}" -f $machine.IsAdmin)
Write-Host ''

if (-not $machine.IsAdmin -and -not $NoAdmin -and -not $DryRun) {
    Write-Warn 'Run this from an elevated PowerShell window.'
    Write-Warn 'Right-click Start, choose Terminal (Admin) or PowerShell (Admin), then re-run.'
    Write-Warn 'Use -DryRun to preview the plan without admin.'
    exit 2
}

$plan = @(Get-StepPlan -RepoRoot $repoRoot -From $From -Only $Only)
if ($SkipUpdates) {
    $plan = @($plan | Where-Object { $_ -ne '15-updates' })
}
if ($plan.Count -eq 0) {
    Write-Fail 'No steps matched. Check -From and -Only values.'
}

Write-Log ("plan: {0}" -f ($plan -join ' -> '))
if ($SkipUpdates) {
    Write-Warn 'Skipping 15-updates. This machine stays unpatched until you run it.'
    if (-not $DryRun) {
        Suspend-WindowsUpdate -Days 7 | Out-Null
        Write-Warn 'A stuck feature update keeps retrying unless you restart, which rolls the attempt back.'
    }
}
if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry run. Steps that would run:' -ForegroundColor Cyan
    $plan | ForEach-Object { Write-Host ("  - {0}" -f $_) }
    exit 0
}

$started = Get-Date
$script:stepResults = @()
$bootstrapPath = $MyInvocation.MyCommand.Path

function Invoke-Step {
    param([Parameter(Mandatory = $true)][string]$Step)

    $path = Join-Path $repoRoot ("steps/{0}.ps1" -f $Step)
    $stepStart = Get-Date
    Write-StepHeader $Step
    try {
        & $path
    }
    catch {
        $failure = $_.Exception.Message
        $script:stepResults += [pscustomobject]@{
            step    = $Step
            status  = 'failed'
            seconds = [math]::Round(((Get-Date) - $stepStart).TotalSeconds, 1)
            error   = $failure
        }
        try { Save-RunSummary -Status 'failed' -Started $started -Steps $script:stepResults }
        catch { Write-Warn ("run summary failed: {0}" -f $_.Exception.Message) }
        Write-Fail ("step {0} failed: {1} | resume: .\bootstrap.ps1 -From {0}" -f $Step, $failure)
    }
    $script:stepResults += [pscustomobject]@{
        step    = $Step
        status  = 'ok'
        seconds = [math]::Round(((Get-Date) - $stepStart).TotalSeconds, 1)
    }
    Write-Log ("step {0} took {1:n1}s" -f $Step, ((Get-Date) - $stepStart).TotalSeconds)
}

# Winget takes a global installer lock, so winget steps stay serial. The
# sidecar steps use mise, PSGallery and git instead, which is why they can
# run while 27-apps downloads.
$sidecarNames = @('47-pwsh-modules')
$useParallel = $Parallel -and ($plan -contains '27-apps')
$sidecars = @()
$serialPlan = $plan
if ($useParallel) {
    $sidecars = @($plan | Where-Object { $sidecarNames -contains $_ })
    $serialPlan = @($plan | Where-Object { $sidecarNames -notcontains $_ })
}

$children = @()
$appsIndex = [Array]::IndexOf($serialPlan, '27-apps')
for ($index = 0; $index -lt $serialPlan.Count; $index++) {
    if ($useParallel -and $index -eq $appsIndex -and $sidecars.Count -gt 0) {
        foreach ($sidecar in $sidecars) {
            Write-Log ("starting in parallel: {0}" -f $sidecar)
            $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Only {1} -SkipUpdates -Yes' -f $bootstrapPath, $sidecar
            $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru
            $children += [pscustomobject]@{ Step = $sidecar; Process = $process }
        }
    }
    Invoke-Step -Step $serialPlan[$index]
}

foreach ($child in $children) {
    $child.Process.WaitForExit()
    if ($child.Process.ExitCode -ne 0) {
        Write-Fail ("parallel step failed: {0} (exit {1}) | resume: .\bootstrap.ps1 -Only {0}" -f $child.Step, $child.Process.ExitCode)
    }
    Write-Ok ("parallel step finished: {0}" -f $child.Step)
}

try { Save-RunSummary -Status 'ok' -Started $started -Steps $script:stepResults }
catch { Write-Warn ("run summary failed: {0}" -f $_.Exception.Message) }
$elapsed = (Get-Date) - $started
Write-Host ''
Write-Ok ("bootstrap finished in {0:n1} minutes" -f $elapsed.TotalMinutes)
Write-Log ("log: {0}" -f $global:OliLogFile)

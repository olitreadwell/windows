#Requires -Version 5.1
<#
.SYNOPSIS
Provision a Windows machine from zero to daily driver.

.DESCRIPTION
Runs numbered steps in order. Every step detects its own completion, so
re-running is safe. Nothing deletes user data; an overwritten config is
backed up first.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -From 40-dotfiles
#>
[CmdletBinding()]
param(
    [string]$From,
    [string]$Only,
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
if ($plan.Count -eq 0) {
    Write-Fail 'No steps matched. Check -From and -Only values.'
}

Write-Log ("plan: {0}" -f ($plan -join ' -> '))
if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry run. Steps that would run:' -ForegroundColor Cyan
    $plan | ForEach-Object { Write-Host ("  - {0}" -f $_) }
    exit 0
}

$started = Get-Date
foreach ($step in $plan) {
    $path = Join-Path $repoRoot ("steps/{0}.ps1" -f $step)
    Write-StepHeader $step
    try {
        & $path
    }
    catch {
        Write-Fail ("step {0} failed: {1} | resume: .\bootstrap.ps1 -From {0}" -f $step, $_.Exception.Message)
    }
}

$elapsed = (Get-Date) - $started
Write-Host ''
Write-Ok ("bootstrap finished in {0:n1} minutes" -f $elapsed.TotalMinutes)
Write-Log ("log: {0}" -f $global:OliLogFile)

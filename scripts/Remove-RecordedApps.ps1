#Requires -Version 5.1
<#
.SYNOPSIS
Remove packages that this repo installed, from the install record.

.DESCRIPTION
Reads %LOCALAPPDATA%\oli-windows\installed-packages.jsonl. Dry run by
default: prints what would be removed. Pass -Apply to uninstall.

.EXAMPLE
.\scripts\Remove-RecordedApps.ps1

.EXAMPLE
.\scripts\Remove-RecordedApps.ps1 -Apply
#>
[CmdletBinding()]
param([switch]$Apply)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$base = $env:LOCALAPPDATA
if (-not $base) { $base = Join-Path $HOME '.local/state' }
$record = Join-Path $base 'oli-windows/installed-packages.jsonl'

if (-not (Test-Path $record)) {
    Write-Warning "no install record: $record"
    exit 2
}

$packages = @()
foreach ($line in Get-Content -LiteralPath $record) {
    if (-not $line.Trim()) { continue }
    try { $packages += ($line | ConvertFrom-Json) } catch { }
}
$packages = @($packages | Sort-Object at -Descending | Group-Object id | ForEach-Object { $_.Group[0] } | Sort-Object name)

Write-Host ("recorded packages: {0}" -f $packages.Count) -ForegroundColor Cyan
$packages | Format-Table name, id, at -AutoSize

if (-not $Apply) {
    Write-Host 'Dry run. Re-run with -Apply to uninstall these.' -ForegroundColor Yellow
    exit 0
}

foreach ($package in $packages) {
    Write-Host ("removing: {0}" -f $package.id)
    & winget uninstall --id $package.id --exact --silent --disable-interactivity --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Warning ("uninstall failed: {0}" -f $package.id) }
}
Write-Host 'Done. The record is kept; delete installed-packages.jsonl to reset it.' -ForegroundColor Green

<#
.SYNOPSIS
Uploads the recent bootstrap logs to a secret GitHub gist.

.DESCRIPTION
Collects the last few run logs, errors.log, run summaries, Windows Update
events and a short system report, redacts the account name, and pushes the
result to one secret gist. Re-running updates the same gist, so the URL stays
stable. Needs `gh auth login` once.

.EXAMPLE
.\Send-Logs.ps1

.EXAMPLE
.\Send-Logs.ps1 -Latest 5 -NoUpload
#>
[CmdletBinding()]
param(
    [int]$Latest = 3,
    [switch]$NoUpload
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$stateDir = Join-Path $env:LOCALAPPDATA 'oli-windows'
if (-not $env:LOCALAPPDATA) { $stateDir = Join-Path $HOME '.local/state/oli-windows' }
$logsDir = Join-Path $stateDir 'logs'
$runsDir = Join-Path $stateDir 'runs'

function Read-Tail {
    param([string]$Path, [int]$Lines = 200)
    if (-not (Test-Path -LiteralPath $Path)) { return @("(missing: $Path)") }
    return @(Get-Content -LiteralPath $Path -Tail $Lines -ErrorAction SilentlyContinue)
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Windows bootstrap log')
$report.Add('')
$report.Add(('sent: {0}' -f (Get-Date).ToString('o')))
$report.Add('')

$os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

$report.Add('## System')
$report.Add('')
$report.Add(('- model: {0} {1}' -f $cs.Manufacturer, $cs.Model))
$report.Add(('- windows: {0} build {1}' -f $os.Caption, $os.BuildNumber))
$report.Add(('- cpu: {0}' -f $cpu.Name))
$report.Add(('- memory: {0} GB' -f [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)))
$report.Add(('- free disk: {0} GB' -f [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)))
$report.Add(('- powershell: {0}' -f $PSVersionTable.PSVersion))
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    $wingetVersion = (& winget --version 2>$null) -join ' '
    $report.Add(('- winget: {0}' -f $wingetVersion))
}
$report.Add('')

$report.Add('## errors.log (tail 200)')
$report.Add('')
$report.Add('```')
$report.AddRange([string[]](Read-Tail -Path (Join-Path $stateDir 'errors.log') -Lines 200))
$report.Add('```')
$report.Add('')

$report.Add('## bootstrap.log (tail 400)')
$report.Add('')
$report.Add('```')
$report.AddRange([string[]](Read-Tail -Path (Join-Path $stateDir 'bootstrap.log') -Lines 400))
$report.Add('```')
$report.Add('')

if (Test-Path $logsDir) {
    $runLogs = @(Get-ChildItem -Path $logsDir -Filter '*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First $Latest)
    foreach ($log in $runLogs) {
        $report.Add(('## run log: {0}' -f $log.Name))
        $report.Add('')
        $report.Add('```')
        $report.AddRange([string[]](Read-Tail -Path $log.FullName -Lines 400))
        $report.Add('```')
        $report.Add('')
    }
}

if (Test-Path $runsDir) {
    $summaries = @(Get-ChildItem -Path $runsDir -Filter '*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($summary in $summaries) {
        $report.Add(('## run summary: {0}' -f $summary.Name))
        $report.Add('')
        $report.Add('```json')
        $report.AddRange([string[]](Read-Tail -Path $summary.FullName -Lines 200))
        $report.Add('```')
        $report.Add('')
    }
}

try {
    $updates = Get-WinEvent -LogName 'Microsoft-Windows-WindowsUpdateClient/Operational' -MaxEvents 40 -ErrorAction Stop
    $report.Add('## Windows Update events (last 40)')
    $report.Add('')
    $report.Add('```')
    foreach ($event in $updates) {
        $report.Add(('{0} [{1}] {2}' -f $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), $event.Id, ($event.Message -replace '\s+', ' ')))
    }
    $report.Add('```')
    $report.Add('')
}
catch {
    $report.Add('## Windows Update events')
    $report.Add('')
    $report.Add('(unavailable)')
    $report.Add('')
}

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    $report.Add('## winget list (first 400 lines)')
    $report.Add('')
    $report.Add('```')
    $report.AddRange([string[]]@((& winget list --accept-source-agreements 2>$null) | Select-Object -First 400))
    $report.Add('```')
    $report.Add('')
}

$text = $report -join "`n"
$profilePath = [Environment]::GetFolderPath('UserProfile')
$userName = $env:USERNAME
foreach ($needle in @($profilePath, "C:\Users\$userName")) {
    if ($needle) { $text = $text.Replace($needle, '%USERPROFILE%') }
}
if ($userName) { $text = $text.Replace("\$userName\", '\%USERNAME%\') }
$text = [regex]::Replace($text, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<email>')

$outFile = Join-Path $env:TEMP 'oli-windows-logs.md'
Set-Content -Path $outFile -Value $text -Encoding UTF8
Write-Host ("report: {0} ({1} KB)" -f $outFile, [math]::Round((Get-Item $outFile).Length / 1KB, 1))

if ($NoUpload) { Write-Host 'NoUpload set; not sending.'; return }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warning 'gh is not installed. Install GitHub CLI, run gh auth login, then retry.'
    return
}
& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'gh is not signed in. Run: gh auth login --web'
    return
}

$idFile = Join-Path $stateDir 'log-gist-id.txt'
$id = $null
if (Test-Path $idFile) { $id = (Get-Content -LiteralPath $idFile -First 1).Trim() }

if ($id) {
    & gh gist edit $id $outFile 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "gist update failed for $id; creating a new one"
        $id = $null
    }
}

if (-not $id) {
    $id = (& gh gist create --desc 'Windows bootstrap logs' $outFile 2>$null | Select-Object -Last 1)
    if ($LASTEXITCODE -ne 0 -or -not $id) {
        Write-Warning ('gist upload failed. Report left at: {0}' -f $outFile)
        return
    }
    $id = ($id -split '/')[-1].Trim()
    Set-Content -Path $idFile -Value $id -Encoding UTF8
}

Write-Host ''
Write-Host ("gist: https://gist.github.com/{0}" -f $id) -ForegroundColor Green

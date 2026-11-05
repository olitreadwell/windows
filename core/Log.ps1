# Shared logging for every step. Dot-source from bootstrap.ps1.
#
# Three files under %LOCALAPPDATA%\oli-windows:
#   bootstrap.log  one append-only history across every run
#   errors.log     every ERROR line, for a quick audit
#   logs\*.log     one file per run, rotated to the last 30
Set-StrictMode -Version 2.0

function Initialize-Log {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $global:OliRepoRoot = $RepoRoot
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = Join-Path $HOME '.local/state' }
    $global:OliStateDir = Join-Path $base 'oli-windows'
    $global:OliRunId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $PID
    $global:OliRunSteps = @()

    $logsDir = Join-Path $global:OliStateDir 'logs'
    $runsDir = Join-Path $global:OliStateDir 'runs'
    foreach ($dir in @($global:OliStateDir, $logsDir, $runsDir)) {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }

    $global:OliLogFile = Join-Path $global:OliStateDir 'bootstrap.log'
    $global:OliErrorLog = Join-Path $global:OliStateDir 'errors.log'
    $global:OliRunLog = Join-Path $logsDir ("{0}-bootstrap.log" -f $global:OliRunId)

    # Keep the last 30 run logs. Only files this function creates are touched.
    $old = Get-ChildItem -Path $logsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 29
    foreach ($file in $old) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue }
}

function Add-LogLine {
    param(
        [Parameter(Mandatory = $true)][string]$Line,
        [string]$Kind = 'INFO'
    )

    foreach ($path in @($global:OliRunLog, $global:OliLogFile)) {
        if ($path) { Add-Content -Path $path -Value $Line -Encoding UTF8 }
    }
    if ($Kind -eq 'ERROR' -and $global:OliErrorLog) {
        Add-Content -Path $global:OliErrorLog -Value $Line -Encoding UTF8
    }
}

function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-LogLine -Line $line
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor DarkGray
}

function Write-Ok {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[{0}] OK: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-LogLine -Line $line
    Write-Host ("[{0}] OK   {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[{0}] WARN: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-LogLine -Line $line
    Write-Host ("[{0}] WARN {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Yellow
}

function Write-Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = "[{0}] ERROR: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-LogLine -Line $line -Kind 'ERROR'
    Write-Host ("[{0}] ERROR {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Red
    throw $Message
}

function Write-StepHeader {
    param([Parameter(Mandatory = $true)][string]$Name)
    Write-Host ''
    Write-Host ("==> {0}" -f $Name) -ForegroundColor Cyan
    Add-LogLine -Line ("==> step: {0}" -f $Name)
}

function Save-RunSummary {
    <#
    Writes runs\<id>.json with the plan, per-step status and duration, and the
    machine facts. Safe to call on a failed run.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][datetime]$Started,
        [object[]]$Steps = @()
    )

    $facts = $null
    try { $facts = Get-MachineInfo } catch { $facts = $null }

    $summary = [pscustomobject]@{
        runId    = $global:OliRunId
        status   = $Status
        started  = $Started.ToString('o')
        finished = (Get-Date).ToString('o')
        minutes  = [math]::Round(((Get-Date) - $Started).TotalMinutes, 1)
        machine  = $facts
        steps    = $Steps
        log      = $global:OliRunLog
    }

    $path = Join-Path $global:OliStateDir ('runs/{0}.json' -f $global:OliRunId)
    $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
    Write-Log ("run summary: {0}" -f $path)
}

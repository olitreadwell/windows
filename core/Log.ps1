# Shared logging for every step. Dot-source from bootstrap.ps1.
Set-StrictMode -Version 2.0

function Initialize-Log {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $global:OliRepoRoot = $RepoRoot
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = Join-Path $HOME '.local/state' }
    $global:OliStateDir = Join-Path $base 'oli-windows'
    $global:OliLogFile = Join-Path $global:OliStateDir 'bootstrap.log'

    if (-not (Test-Path $global:OliStateDir)) {
        New-Item -ItemType Directory -Path $global:OliStateDir -Force | Out-Null
    }
}

function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$stamp] $Message"
    if ($global:OliLogFile) {
        Add-Content -Path $global:OliLogFile -Value $line -Encoding UTF8
    }
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor DarkGray
}

function Write-Ok {
    param([Parameter(Mandatory = $true)][string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($global:OliLogFile) {
        Add-Content -Path $global:OliLogFile -Value "[$stamp] OK: $Message" -Encoding UTF8
    }
    Write-Host ("[{0}] OK   {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory = $true)][string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($global:OliLogFile) {
        Add-Content -Path $global:OliLogFile -Value "[$stamp] WARN: $Message" -Encoding UTF8
    }
    Write-Host ("[{0}] WARN {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Yellow
}

function Write-Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($global:OliLogFile) {
        Add-Content -Path $global:OliLogFile -Value "[$stamp] ERROR: $Message" -Encoding UTF8
    }
    Write-Host ("[{0}] ERROR {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor Red
    throw $Message
}

function Write-StepHeader {
    param([Parameter(Mandatory = $true)][string]$Name)
    Write-Host ''
    Write-Host ("==> {0}" -f $Name) -ForegroundColor Cyan
    Add-Content -Path $global:OliLogFile -Value ("==> step: {0}" -f $Name) -Encoding UTF8
}

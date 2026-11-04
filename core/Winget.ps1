# winget helpers. One package list, two sections: [core] and [apps].
Set-StrictMode -Version 2.0

function Get-PackageSection {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Section
    )

    $inSection = $false
    $packages = @()
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -match '^\[(.+)\]$') {
            $inSection = ($Matches[1] -eq $Section)
            continue
        }
        if (-not $inSection -or $line -eq '' -or $line.StartsWith('#')) { continue }
        $packages += $line
    }
    return $packages
}

function Test-WingetPackage {
    param([Parameter(Mandatory = $true)][string]$Id)

    $output = & winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    return [bool](($output -join "`n") -match [regex]::Escape($Id))
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Name
    )

    if (-not $Name) { $Name = $Id }

    if (Test-WingetPackage -Id $Id) {
        Write-Log "already installed: $Name ($Id)"
        return $true
    }

    Write-Log "installing: $Name ($Id)"
    & winget install --id $Id --exact --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "winget failed: $Name ($Id) exit $LASTEXITCODE"
        return $false
    }

    Write-Ok "installed: $Name ($Id)"
    Update-SessionPath
    return $true
}

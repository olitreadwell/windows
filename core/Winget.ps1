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

function Test-WingetAvailable {
    if (-not (Test-CommandWorks -Name 'winget')) {
        Write-Warn 'winget is not on PATH. Install App Installer, then re-run 20-winget.'
        return $false
    }
    return $true
}

function Test-WingetPackage {
    param([Parameter(Mandatory = $true)][string]$Id)

    if (-not (Test-WingetAvailable)) { return $false }

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
    if (-not (Test-WingetAvailable)) { return $false }

    if (Test-WingetPackage -Id $Id) {
        Write-Log "already installed: $Name ($Id)"
        return $true
    }

    Write-Log "installing: $Name ($Id)"
    # A running GUI app can block its own upgrade behind a hidden installer
    # prompt. 1Password is the common case on this machine.
    if ($Id -eq 'AgileBits.1Password') {
        Get-Process -Name '1Password' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $argumentLine = 'install --id {0} --exact --silent --disable-interactivity --accept-source-agreements --accept-package-agreements' -f $Id
    $timeoutMinutes = 5
    if ($env:OLI_WINGET_TIMEOUT_MINUTES -match '^\d+$') { $timeoutMinutes = [int]$env:OLI_WINGET_TIMEOUT_MINUTES }
    $process = Start-Process -FilePath 'winget.exe' -ArgumentList $argumentLine -NoNewWindow -PassThru
    if (-not $process.WaitForExit($timeoutMinutes * 60000)) {
        $process.Kill()
        Write-Warn ("winget timed out after {0} minutes: {1} ({2}). Close the app and re-run." -f $timeoutMinutes, $Name, $Id)
        Write-Warn 'Override with: $env:OLI_WINGET_TIMEOUT_MINUTES = 15'
        return $false
    }
    if ($process.ExitCode -ne 0) {
        Write-Warn "winget failed: $Name ($Id) exit $($process.ExitCode)"
        return $false
    }

    Write-Ok "installed: $Name ($Id)"
    Update-SessionPath
    if (-not (Test-WingetPackage -Id $Id)) {
        Write-Warn ("winget exited 0 but {0} is not listed by 'winget list'. Check the Start menu, or reinstall with the vendor installer." -f $Id)
    }
    return $true
}

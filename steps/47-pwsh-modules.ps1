# PowerShell module bundle. This is the closest Windows has to an oh-my-zsh
# plugin set: fuzzy history and files, plus file icons in Get-ChildItem.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$modules = @('PSFzf', 'Terminal-Icons')
$missing = @($modules | Where-Object { -not (Get-Module -ListAvailable -Name $_) })
if ($missing.Count -eq 0) {
    Write-Ok 'PowerShell modules already installed'
    return
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
    if (-not $nuget) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($repository -and $repository.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    }

    foreach ($name in $missing) {
        Install-Module -Name $name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Ok ("installed module: {0}" -f $name)
    }
}
catch {
    Write-Warn ("PowerShell module install failed: {0}" -f $_.Exception.Message)
    Write-Warn 'Skipped. The profile keeps its built-in fzf key bindings.'
}

Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Write-Ok 'PowerShell module step finished'

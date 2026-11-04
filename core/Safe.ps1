# Filesystem and privilege helpers. Nothing here deletes user data.
Set-StrictMode -Version 2.0

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-StateDir {
    if (-not (Test-Path $global:OliStateDir)) {
        New-Item -ItemType Directory -Path $global:OliStateDir -Force | Out-Null
    }
    return $global:OliStateDir
}

function Backup-Path {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $backup = "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmssfff')"
    if (Test-Path -LiteralPath $backup) { $backup = "$backup-$PID" }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        Copy-Item -LiteralPath $Path -Destination $backup -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $Path -Destination $backup -Force
    }
    Write-Log "backed up: $Path -> $backup"
    return $backup
}

function Test-LinkTarget {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    foreach ($target in @($Item.Target)) {
        if (-not $target) { continue }
        try {
            if ((Resolve-Path -LiteralPath $target -ErrorAction Stop).Path -eq $SourcePath) { return $true }
        }
        catch { Write-Verbose "dangling link target: $target" }
    }
    return $false
}

function Test-RebootPending {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $true }
    }
    return $false
}

function Remove-ManagedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        # Remove the link itself, never the target.
        if ($item.PSIsContainer) { [IO.Directory]::Delete($Path, $false) }
        else { [IO.File]::Delete($Path) }
        return
    }
    Remove-Item -LiteralPath $Path -Recurse -Force
}

function Set-ManagedFile {
    <#
    Keeps a config file pointing at the repo copy. Hard link first (works
    without admin, same volume), then symlink, then a plain copy. A real file
    that differs is backed up before anything changes.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$CopyOnly
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warn "managed source missing: $Source"
        return $false
    }

    $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if (Test-LinkTarget -Item $item -SourcePath $sourcePath) { return $true }
            Remove-ManagedPath -Path $Destination
        }
        elseif (-not $item.PSIsContainer) {
            $sourceHash = (Get-FileHash -LiteralPath $sourcePath).Hash
            $destinationHash = (Get-FileHash -LiteralPath $Destination).Hash
            if ($sourceHash -eq $destinationHash) { return $true }
            $null = Backup-Path -Path $Destination
            Remove-Item -LiteralPath $Destination -Force
        }
        else {
            $null = Backup-Path -Path $Destination
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }
    }

    if ($CopyOnly) {
        Copy-Item -LiteralPath $sourcePath -Destination $Destination -Force
        Write-Ok "copied: $Destination"
        return $true
    }

    try {
        New-Item -ItemType HardLink -Path $Destination -Target $sourcePath -ErrorAction Stop | Out-Null
        Write-Ok "hardlinked: $Destination"
        return $true
    }
    catch { Write-Verbose "hard link unavailable: $Destination" }

    try {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $sourcePath -ErrorAction Stop | Out-Null
        Write-Ok "symlinked: $Destination"
        return $true
    }
    catch { Write-Verbose "symlink unavailable: $Destination" }

    Copy-Item -LiteralPath $sourcePath -Destination $Destination -Force
    Write-Ok "copied (no link privilege): $Destination"
    return $true
}

function Set-ManagedDirectory {
    <#
    Junctions need no admin rights and behave like a directory symlink for
    every tool that reads the skills tree.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warn "managed source missing: $Source"
        return $false
    }

    $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if (Test-LinkTarget -Item $item -SourcePath $sourcePath) { return $true }
            Remove-ManagedPath -Path $Destination
        }
        else {
            $null = Backup-Path -Path $Destination
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }
    }

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    try {
        New-Item -ItemType Junction -Path $Destination -Target $sourcePath -ErrorAction Stop | Out-Null
        $created = Get-Item -LiteralPath $Destination -Force -ErrorAction Stop
        if (-not (Test-LinkTarget -Item $created -SourcePath $sourcePath)) {
            throw 'junction did not point at the source'
        }
        Write-Ok "junction: $Destination"
        return $true
    }
    catch {
        Write-Verbose "junction unavailable: $Destination"
        Copy-Item -LiteralPath $sourcePath -Destination $Destination -Recurse -Force
        Write-Ok "copied (junction unavailable): $Destination"
        return $true
    }
}

function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

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

function Test-CommandWorks {
    <#
    A command can resolve and still be a broken WindowsApps alias stub, which
    is how pwsh failed with "no applicable licenses" on a real machine.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Arguments = @('--version')
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { return $false }
    try {
        $output = & $Name @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        return (($output -join ' ').Trim().Length -gt 0)
    }
    catch {
        return $false
    }
}

function Get-RegistryValue {
    <#
    Reads one registry value and returns $null when the key or value is
    missing. Accessing a missing property directly throws under
    Set-StrictMode -Version 2.0, which is what broke step 12 on a fresh
    Windows install.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    }
    catch {
        return $null
    }
}

function Suspend-WindowsUpdate {
    <#
    Pauses feature and quality updates for a few days. Used by -SkipUpdates
    so a stuck feature install stops being retried while the machine gets
    provisioned. It does not cancel a setup already in progress; a restart
    rolls that attempt back.
    #>
    param([int]$Days = 7)

    if (-not (Test-IsAdmin)) {
        Write-Warn 'Windows Update pause needs admin. Run elevated to pause it.'
        return $false
    }

    $key = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

    $start = (Get-Date).ToUniversalTime()
    $end = $start.AddDays($Days)
    $format = 'yyyy-MM-ddTHH:mm:ssZ'
    $values = @{
        PauseUpdatesStartTime        = $start.ToString($format)
        PauseUpdatesExpiryTime       = $end.ToString($format)
        PauseFeatureUpdatesStartTime = $start.ToString($format)
        PauseFeatureUpdatesEndTime   = $end.ToString($format)
        PauseQualityUpdatesStartTime = $start.ToString($format)
        PauseQualityUpdatesEndTime   = $end.ToString($format)
    }
    foreach ($name in $values.Keys) {
        Set-ItemProperty -Path $key -Name $name -Value $values[$name] -Type String -ErrorAction SilentlyContinue
    }

    $check = Get-RegistryValue -Path $key -Name PauseUpdatesExpiryTime
    if ($check) {
        Write-Ok ("Windows Update paused until {0}" -f $end.ToString('yyyy-MM-dd'))
        return $true
    }
    Write-Warn 'Windows Update pause was not recorded. Pause it manually in Settings.'
    return $false
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

function Reset-WindowsUpdateState {
    <#
    Renames the Windows Update download cache and the feature-update staging
    folders, then restarts the services. Renaming keeps the old state for
    rollback; nothing is deleted. Safe to run twice.
    #>
    param([string]$Reason = 'update reset')

    if (-not (Test-IsAdmin)) {
        Write-Warn ("{0} needs admin. Run from an elevated shell." -f $Reason)
        return $false
    }

    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    $services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver', 'dosvc', 'usosvc')
    foreach ($name in $services) {
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $service -or $service.Status -eq 'Stopped') { continue }
        try { Stop-Service -Name $name -Force -ErrorAction Stop }
        catch { Write-Warn ("could not stop {0}: {1}" -f $name, $_.Exception.Message) }
    }
    Write-Ok 'update services stopped'

    $paths = @(
        (Join-Path $env:SystemRoot 'SoftwareDistribution'),
        (Join-Path $env:SystemRoot 'System32\catroot2'),
        (Join-Path $env:SystemDrive '$WINDOWS.~BT'),
        (Join-Path $env:SystemDrive '$WINDOWS.~WS')
    )
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $backup = "{0}.old-{1}" -f $path, $stamp
        try {
            Move-Item -LiteralPath $path -Destination $backup -Force -ErrorAction Stop
            Write-Ok ("moved aside: {0}" -f $path)
        }
        catch {
            Write-Warn ("could not move {0}: {1}" -f $path, $_.Exception.Message)
        }
    }

    foreach ($name in $services) {
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $service) { continue }
        try { Start-Service -Name $name -ErrorAction Stop }
        catch { Write-Warn ("could not start {0}: {1}" -f $name, $_.Exception.Message) }
    }
    Write-Ok 'update services restarted'
    return $true
}

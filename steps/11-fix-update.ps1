# Opt-in Windows Update reset. Renames the download cache and the update
# staging folders so a wedged feature update stops retrying. Only runs with
# -FixUpdate, and never reboots by itself.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliFixUpdate -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'Windows Update reset skipped. Use -FixUpdate to run it.'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'The update reset needs admin. Run from an elevated shell.'
    return
}

$build = [Environment]::OSVersion.Version.Build
$freeGb = [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
Write-Log ("reset: build {0}, {1} GB free" -f $build, $freeGb)
if ($freeGb -lt 20) {
    Write-Warn ("only {0} GB free. Free space before retrying the upgrade." -f $freeGb)
}

Reset-WindowsUpdateState -Reason 'Windows Update reset' | Out-Null

Write-Warn 'Restart now, then run: .\bootstrap.ps1 -Only 16-win10 -Windows10'
Write-Warn 'The old caches stay on disk as *.old-<timestamp>; delete them yourself once the upgrade works.'

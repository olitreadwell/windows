# GUI apps. Keep this list short; add one line to config/packages.txt instead.
Set-StrictMode -Version 2.0

$packages = Get-PackageSection -Path (Join-Path $global:OliRepoRoot 'config/packages.txt') -Section 'apps'
if ($packages.Count -eq 0) {
    Write-Log 'no [apps] entries'
    return
}

$failed = @()
foreach ($id in $packages) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}

if ($failed.Count -gt 0) {
    Write-Warn ("app installs failed: {0}" -f ($failed -join ', '))
}
else {
    Write-Ok 'apps installed'
}

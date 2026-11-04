# Core CLI tools. All installs are idempotent.
Set-StrictMode -Version 2.0

$packages = Get-PackageSection -Path (Join-Path $global:OliRepoRoot 'config/packages.txt') -Section 'core'
if ($packages.Count -eq 0) {
    Write-Fail 'config/packages.txt has no [core] entries'
}

$failed = @()
foreach ($id in $packages) {
    if (-not (Install-WingetPackage -Id $id)) { $failed += $id }
}

Update-SessionPath
if ($failed.Count -gt 0) {
    Write-Warn ("core packages failed: {0}" -f ($failed -join ', '))
    Write-Warn 'Re-run this step after fixing the failures.'
}
else {
    Write-Ok 'core CLI tools installed'
}

if (Test-CommandExists 'pwsh') {
    Write-Ok ("PowerShell 7: {0}" -f ((& pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') -join ' '))
}

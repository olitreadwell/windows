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

$missingApps = @()
foreach ($id in $packages) {
    if (-not (Test-WingetPackage -Id $id)) { $missingApps += $id }
}
if ($missingApps.Count -gt 0) {
    Write-Warn ("winget does not list these apps: {0}" -f ($missingApps -join ', '))
    Write-Warn 'Open the Start menu and search by name before reinstalling.'
}

# Windows validates the default-browser choice with a hash and ignores a
# scripted write, so the best a script can do is detect the gap and open the
# right page. Zen is a Firefox fork and registers itself as a candidate.
$htmlChoice = Get-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.html\UserChoice' -Name ProgId
if ($htmlChoice -and $htmlChoice -match 'Zen') {
    Write-Ok 'default browser is Zen'
}
else {
    if ($htmlChoice) { Write-Warn ("default browser is {0}; Windows blocks a scripted change" -f $htmlChoice) }
    else { Write-Warn 'no default browser is recorded; Windows blocks a scripted change' }
    Write-Warn 'Choose Zen Browser in the page that opens, or run: defaultapps'
    Start-Process 'ms-settings:defaultapps'
}

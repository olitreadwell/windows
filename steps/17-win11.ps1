# Opt-in Windows 11 upgrade. Downloads Microsoft's Installation Assistant
# and runs it, so the upgrade does not depend on Windows Update succeeding.
# Only runs with -Windows11.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliWindows11 -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'Windows 11 upgrade skipped. Use -Windows11 to run it.'
    return
}

$build = [Environment]::OSVersion.Version.Build
if ($build -ge 22000) {
    Write-Ok 'already on Windows 11'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'Windows 11 upgrade needs admin. Run from an elevated shell.'
    return
}

if (Test-RebootPending) {
    Write-Fail 'A restart is pending. Restart, then run: .\bootstrap.ps1 -Only 17-win11'
}

$freeGb = [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
if ($freeGb -lt 25) {
    Write-Fail ("only {0} GB free; the upgrade needs about 25 GB" -f $freeGb)
}

$problems = @()

try {
    $tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName 'Win32_Tpm' -ErrorAction Stop
    if (-not $tpm) {
        $problems += 'no TPM reported'
    }
    elseif ($tpm.SpecVersion -notmatch '^2\.0') {
        $problems += ("TPM {0}, Windows 11 needs 2.0" -f $tpm.SpecVersion)
    }
    elseif (-not $tpm.IsEnabled_InitialValue) {
        $problems += 'TPM is present but disabled in firmware'
    }
}
catch {
    $problems += 'TPM state could not be read'
}

try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    if (-not $secureBoot) { $problems += 'Secure Boot is off; enable it in firmware (Surface: hold Volume Up while powering on)' }
}
catch {
    $problems += 'Secure Boot is unavailable, so the machine is booting in legacy mode'
}

if ($problems.Count -gt 0) {
    foreach ($problem in $problems) { Write-Warn $problem }
    Write-Fail 'This machine does not meet the Windows 11 requirements yet. Fix the warnings, then re-run: .\bootstrap.ps1 -Only 17-win11'
}

$machine = Get-MachineInfo
Write-Log ("upgrading: {0} {1}, build {2}" -f $machine.Manufacturer, $machine.Model, $build)

if (-not $global:OliAssumeYes) {
    Write-Warn 'This downloads Microsoft''s Installation Assistant and starts an in-place upgrade.'
    Write-Warn 'Windows restarts several times. Save your work first.'
    $answer = Read-Host 'Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Warn 'Upgrade cancelled'
        return
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$downloads = Join-Path $HOME 'Downloads'
if (-not (Test-Path $downloads)) { New-Item -ItemType Directory -Path $downloads -Force | Out-Null }
$installer = Join-Path $downloads 'Windows11InstallationAssistant.exe'

try {
    Write-Log 'downloading the Windows 11 Installation Assistant'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2171764' -OutFile $installer -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Fail ("download failed: {0}. Manual fallback: https://www.microsoft.com/software-download/windows11" -f $_.Exception.Message)
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $installer).Length / 1MB, 1)
if ($sizeMb -lt 2) {
    Write-Fail ("downloaded file is only {0} MB, which is not the installer. Delete it and try again." -f $sizeMb)
}

$signature = Get-AuthenticodeSignature -FilePath $installer -ErrorAction SilentlyContinue
if (-not $signature -or $signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
    Write-Fail 'installer signature is not a valid Microsoft signature. Refusing to run it.'
}
Write-Ok ("downloaded and verified: {0} ({1} MB)" -f $installer, $sizeMb)

Write-Log 'starting the Installation Assistant. It shows its own progress window.'
$process = Start-Process -FilePath $installer -Verb RunAs -Wait -PassThru

$newBuild = [Environment]::OSVersion.Version.Build
if ($newBuild -ge 22000) {
    Write-Ok 'Windows 11 installed'
    return
}

Write-Warn ("assistant exited {0}; build is still {1}" -f $process.ExitCode, $newBuild)
Write-Warn 'If it reported that the PC cannot run Windows 11, enable TPM 2.0 and Secure Boot in firmware.'
Write-Warn 'Manual fallback: https://www.microsoft.com/software-download/windows11, download the ISO, mount it, run setup.exe.'
Write-Warn 'For a clean install instead, use the Media Creation Tool and a USB stick with at least 8 GB.'

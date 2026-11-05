# Opt-in Windows 10 22H2 upgrade. Downloads Microsoft's Update Assistant
# and runs it, so the upgrade does not depend on Windows Update succeeding.
# Only runs with -Windows10.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliWindows10 -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'Windows 10 22H2 upgrade skipped. Use -Windows10 to run it.'
    return
}

$build = [Environment]::OSVersion.Version.Build
if ($build -ge 19045) {
    Write-Ok 'already on Windows 10 22H2'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'Windows 10 upgrade needs admin. Run from an elevated shell.'
    return
}

$freeGb = [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
if ($freeGb -lt 20) {
    Write-Fail ("only {0} GB free; the upgrade needs about 20 GB" -f $freeGb)
}

if (Test-RebootPending) {
    Write-Warn 'A restart is pending. The assistant will ask for it again after it starts.'
}

$machine = Get-MachineInfo
Write-Log ("upgrading: {0} {1}, build {2}" -f $machine.Manufacturer, $machine.Model, $build)

if (-not $global:OliAssumeYes) {
    Write-Warn 'This downloads Microsoft''s Windows 10 Update Assistant and starts an in-place upgrade.'
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
$installer = Join-Path $downloads 'Windows10UpdateAssistant.exe'

try {
    Write-Log 'downloading the Windows 10 Update Assistant'
    Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?LinkID=799445' -OutFile $installer -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Fail ("download failed: {0}. Manual fallback: https://www.microsoft.com/software-download/windows10" -f $_.Exception.Message)
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $installer).Length / 1MB, 1)
if ($sizeMb -lt 2) {
    Write-Fail ("downloaded file is only {0} MB, which is not the assistant. Delete it and try again." -f $sizeMb)
}

$signature = Get-AuthenticodeSignature -FilePath $installer -ErrorAction SilentlyContinue
if (-not $signature -or $signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
    Write-Fail 'assistant signature is not a valid Microsoft signature. Refusing to run it.'
}
Write-Ok ("downloaded and verified: {0} ({1} MB)" -f $installer, $sizeMb)

Write-Log 'starting the Update Assistant. It shows its own progress window.'
$process = Start-Process -FilePath $installer -Verb RunAs -Wait -PassThru

$newBuild = [Environment]::OSVersion.Version.Build
if ($newBuild -ge 19045) {
    Write-Ok 'Windows 10 22H2 installed'
    return
}

Write-Warn ("assistant exited {0}; build is still {1}" -f $process.ExitCode, $newBuild)
Write-Warn 'Manual fallback: https://www.microsoft.com/software-download/windows10, download the Media Creation Tool or ISO.'

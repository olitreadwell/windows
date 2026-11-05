# Opt-in OpenSSH server with key-only login from the Mac. Opens port 22 to
# Tailscale only, installs the repo's public key, and turns off remote UAC
# token filtering so an admin session over SSH can run elevated commands.
# Only runs with -EnableSsh.
Set-StrictMode -Version 2.0

$enabled = $false
$flag = Get-Variable -Name OliEnableSsh -Scope Global -ErrorAction SilentlyContinue
if ($flag) { $enabled = [bool]$flag.Value }
if (-not $enabled) {
    Write-Log 'OpenSSH server skipped. Use -EnableSsh to install it.'
    return
}

if (-not (Test-IsAdmin)) {
    Write-Warn 'OpenSSH setup needs admin. Run from an elevated shell.'
    return
}

$keyFile = Join-Path $global:OliRepoRoot 'config/ssh/authorized_key.pub'
if (-not (Test-Path -LiteralPath $keyFile)) {
    Write-Fail ("public key missing: {0}" -f $keyFile)
}
$publicKey = (Get-Content -LiteralPath $keyFile -Raw).Trim()
if (-not $publicKey.StartsWith('ssh-ed25519')) {
    Write-Fail 'authorized_key.pub does not hold an ssh-ed25519 key'
}

$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $capability) {
    Write-Warn 'OpenSSH.Server capability is not listed. Windows 10 1809 or later is required.'
    return
}
if ($capability.State -ne 'Installed') {
    Write-Log 'installing the OpenSSH.Server capability'
    Add-WindowsCapability -Online -Name $capability.Name | Out-Null
    Write-Ok 'OpenSSH.Server installed'
}
else {
    Write-Log 'OpenSSH.Server already installed'
}

Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd
Write-Ok 'sshd running and set to automatic'

$shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$sshKey = 'HKLM:\SOFTWARE\OpenSSH'
if (-not (Test-Path $sshKey)) { New-Item -Path $sshKey -Force | Out-Null }
New-ItemProperty -Path $sshKey -Name DefaultShell -Value $shell -PropertyType String -Force | Out-Null
Write-Ok 'default shell is PowerShell'

$sshProgramData = Join-Path $env:ProgramData 'ssh'
if (-not (Test-Path $sshProgramData)) { New-Item -ItemType Directory -Path $sshProgramData -Force | Out-Null }
$adminKeys = Join-Path $sshProgramData 'administrators_authorized_keys'
$existing = @()
if (Test-Path -LiteralPath $adminKeys) {
    $existing = @(Get-Content -LiteralPath $adminKeys | Where-Object { $_.Trim() })
}
if (-not ($existing -contains $publicKey)) {
    Add-Content -Path $adminKeys -Value $publicKey -Encoding ASCII
    Write-Ok 'public key added for administrators'
}
else {
    Write-Log 'public key already present'
}
& icacls.exe $adminKeys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warn 'icacls failed on administrators_authorized_keys' }

$configPath = Join-Path $sshProgramData 'sshd_config'
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw
    if ($config -notmatch '(?m)^\s*PubkeyAuthentication\s+yes') {
        Add-Content -Path $configPath -Value "`nPubkeyAuthentication yes" -Encoding ASCII
        Write-Ok 'sshd_config: pubkey auth enabled'
    }
}

$ruleName = 'OpenSSH-Server-In-TCP'
$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($rule) {
    Set-NetFirewallRule -Name $ruleName -RemoteAddress '100.64.0.0/10', 'LocalSubnet'
    Write-Ok 'firewall: SSH limited to Tailscale and the local subnet'
}
else {
    New-NetFirewallRule -Name $ruleName -DisplayName 'OpenSSH Server (Tailscale only)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -RemoteAddress '100.64.0.0/10', 'LocalSubnet' | Out-Null
    Write-Ok 'firewall rule created for SSH'
}

# Remote UAC filtering strips the admin token from network logons. With the
# firewall above, only Tailscale peers can reach SSH, so the full token is
# the intended behaviour here.
$systemPolicy = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
New-ItemProperty -Path $systemPolicy -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWord -Force | Out-Null
Write-Ok 'remote admin token enabled for local accounts'

Restart-Service -Name sshd -Force
Write-Ok 'sshd restarted'

$user = '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME
Write-Warn ("Test from the Mac: ssh {0}@100.106.76.17" -f $env:USERNAME)
Write-Warn ("Windows account: {0}" -f $user)

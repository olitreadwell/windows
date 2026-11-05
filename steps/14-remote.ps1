# Remote desktop over Tailscale. RDP is native to Windows Pro, and the
# Surface Book shipped Pro. The firewall rule is limited to the Tailscale
# address range, so the public internet cannot reach port 3389.
Set-StrictMode -Version 2.0

if (-not (Test-IsAdmin)) {
    Write-Warn 'Remote Desktop needs admin. Run from an elevated shell.'
    return
}

$edition = (Get-CimInstance Win32_OperatingSystem).Caption
if ($edition -notmatch 'Pro|Enterprise|Education') {
    Write-Warn ("RDP host needs Windows Pro or better. This is: {0}" -f $edition)
    return
}

$terminalServer = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
if ((Get-RegistryValue -Path $terminalServer -Name fDenyTSConnections) -ne 0) {
    Set-ItemProperty -Path $terminalServer -Name fDenyTSConnections -Value 0 -Type DWord
    Write-Ok 'Remote Desktop enabled'
}
else {
    Write-Ok 'Remote Desktop already enabled'
}

if ((Get-RegistryValue -Path $terminalServer -Name UserAuthentication) -ne 1) {
    Set-ItemProperty -Path $terminalServer -Name UserAuthentication -Value 1 -Type DWord
    Write-Ok 'Network Level Authentication required'
}

try {
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction Stop | Out-Null
    # 100.64.0.0/10 is the Tailscale address range. LocalSubnet keeps the
    # same-network case working.
    Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue |
        Set-NetFirewallRule -RemoteAddress @('100.64.0.0/10', 'LocalSubnet') -ErrorAction SilentlyContinue
    Write-Ok 'RDP firewall rule limited to Tailscale and the local subnet'
}
catch {
    Write-Warn ("Remote Desktop firewall rule not configured: {0}" -f $_.Exception.Message)
}

Write-Warn 'RDP needs the Windows account password, not the PIN. Set one in Settings > Accounts > Sign-in options.'
Write-Warn 'Sign in to Tailscale on this machine before connecting from the Mac.'
Write-Warn 'Mac side: Tailscale plus the Windows App (Microsoft Remote Desktop), host: this machine Tailscale IP.'

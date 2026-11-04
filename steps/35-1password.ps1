# 1Password app, CLI, and the SSH agent pipe.
Set-StrictMode -Version 2.0

if (-not (Test-CommandExists 'op')) {
    Write-Warn 'op CLI is missing. Install AgileBits.1Password.CLI with winget.'
}
else {
    Write-Ok ("op present: {0}" -f ((& op --version) -join ' '))
    & op account list 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok '1Password CLI is signed in'
    }
    else {
        Write-Warn '1Password is not signed in. Open the app, sign in, then run: op signin'
    }
}

$sshDir = Join-Path $HOME '.ssh'
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
$sshConfig = Join-Path $sshDir 'config'

$begin = '# BEGIN oli-windows 1password agent'
$end = '# END oli-windows 1password agent'
$block = @(
    $begin,
    'Host *',
    '  IdentityAgent "//./pipe/openssh-ssh-agent"',
    $end
) -join "`r`n"

$existing = ''
if (Test-Path $sshConfig) { $existing = Get-Content -Raw -LiteralPath $sshConfig }
if ($existing -notmatch [regex]::Escape($begin)) {
    if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { $existing += "`r`n" }
    Set-Content -LiteralPath $sshConfig -Value ($existing + $block + "`r`n") -Encoding ASCII
    Write-Ok 'ssh config: 1Password agent block added'
}
else {
    Write-Ok 'ssh config: 1Password agent block already present'
}

# 1Password binds the system-wide OpenSSH agent pipe. Windows' own agent
# must not hold it.
$service = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq 'Running') {
        Stop-Service -Name ssh-agent -Force -ErrorAction SilentlyContinue
        Write-Ok 'stopped the Windows OpenSSH Authentication Agent service'
    }
    Set-Service -Name ssh-agent -StartupType Disabled -ErrorAction SilentlyContinue
}

Write-Warn 'Enable Settings > Developer > SSH agent in 1Password before using git over SSH.'
Write-Warn 'Use HTTPS remotes until that is done; the bootstrap config uses HTTPS.'

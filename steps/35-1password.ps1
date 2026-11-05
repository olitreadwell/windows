# 1Password app, CLI, and the SSH agent pipe.
Set-StrictMode -Version 2.0

$opReady = $false
if (-not (Test-CommandExists 'op')) {
    Write-Warn 'op CLI is missing. Install AgileBits.1Password.CLI with winget.'
}
else {
    Write-Ok ("op present: {0}" -f ((& op --version) -join ' '))
    & op account list 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $opReady = $true
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
if (Test-Path $sshConfig) { $existing = [string](Get-Content -Raw -LiteralPath $sshConfig) }
if (-not $existing) { $existing = '' }

$pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end) + '\r?\n?'
# SSH uses the first value it finds, so the block goes at the top. Any
# earlier copy is removed first, which also makes a second run a no-op.
$stripped = [regex]::Replace($existing, $pattern, '')
if ($stripped -match [regex]::Escape($begin)) {
    # A BEGIN without a matching END. Cut from the stray marker to the end.
    $index = $stripped.IndexOf($begin)
    $stripped = $stripped.Substring(0, $index)
}
$updated = $block + "`r`n" + $stripped

if ($updated -eq $existing) {
    Write-Ok 'ssh config: 1Password agent block already current'
}
else {
    if (Test-Path $sshConfig) { $null = Backup-Path -Path $sshConfig }
    [IO.File]::WriteAllText($sshConfig, $updated, (New-Object Text.UTF8Encoding($false)))
    Write-Ok 'ssh config: 1Password agent block written'
}

# 1Password binds the system-wide OpenSSH agent pipe. Windows' own agent must
# not hold it, but only change that once 1Password is actually usable.
if ($opReady) {
    $service = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq 'Running') {
            Stop-Service -Name ssh-agent -Force -ErrorAction SilentlyContinue
            Write-Ok 'stopped the Windows OpenSSH Authentication Agent service'
        }
        Set-Service -Name ssh-agent -StartupType Disabled -ErrorAction SilentlyContinue
    }
    Write-Warn 'Enable Settings > Developer > SSH agent in 1Password before using git over SSH.'
}
else {
    Write-Warn 'Left the Windows OpenSSH Authentication Agent service alone until 1Password is signed in.'
}

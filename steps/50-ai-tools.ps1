# Codex CLI, Claude Code, and their first-run auth.
Set-StrictMode -Version 2.0

$packages = Get-PackageSection -Path (Join-Path $global:OliRepoRoot 'config/packages.txt') -Section 'ai'
foreach ($id in $packages) {
    Install-WingetPackage -Id $id | Out-Null
}

Update-SessionPath

$codexConfig = Join-Path $HOME '.codex/config.toml'
$usesOllamaCloud = $false
if (Test-Path $codexConfig) {
    $usesOllamaCloud = [bool](Select-String -LiteralPath $codexConfig -Pattern 'model_provider\s*=\s*"ollama-cloud"' -Quiet)
}

if (Test-CommandExists 'codex') {
    Write-Ok ("codex present: {0}" -f ((& codex --version) -join ' '))
    if ($usesOllamaCloud) {
        $key = [Environment]::GetEnvironmentVariable('OLLAMA_CLOUD_MAX_API_KEY', 'User')
        if ($key) {
            Write-Ok 'OLLAMA_CLOUD_MAX_API_KEY is set for the user'
        }
        elseif ($global:OliAssumeYes) {
            Write-Warn 'OLLAMA_CLOUD_MAX_API_KEY is missing. Set it, then open a new terminal.'
        }
        else {
            $secure = Read-Host 'Paste OLLAMA_CLOUD_MAX_API_KEY' -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            if ($plain) {
                [Environment]::SetEnvironmentVariable('OLLAMA_CLOUD_MAX_API_KEY', $plain, 'User')
                $env:OLLAMA_CLOUD_MAX_API_KEY = $plain
                Write-Ok 'OLLAMA_CLOUD_MAX_API_KEY stored for the user'
            }
        }
    }
    else {
        $authFile = Join-Path $HOME '.codex/auth.json'
        if (Test-Path $authFile) { Write-Ok 'codex is authenticated' }
        elseif ($global:OliAssumeYes) { Write-Warn 'codex is not authenticated. Run: codex login' }
        else { & codex login }
    }
}
else {
    Write-Warn 'codex is not on PATH yet. Open a new terminal and check: codex --version'
}

if (Test-CommandExists 'claude') {
    Write-Ok ("claude present: {0}" -f ((& claude --version) -join ' '))
    & claude auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok 'claude is authenticated'
    }
    elseif ($global:OliAssumeYes) {
        Write-Warn 'claude is not authenticated. Run: claude auth login'
    }
    else {
        & claude auth login
    }
}
else {
    Write-Warn 'claude is not on PATH yet. Open a new terminal and check: claude --version'
}

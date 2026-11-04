# Shared PowerShell profile. Hardlinked from the windows repo by step 40.
$paths = @(
    (Join-Path $HOME 'bin'),
    (Join-Path $HOME '.local\bin'),
    (Join-Path $HOME '.agents\bin')
)
foreach ($path in $paths) {
    if ((Test-Path $path) -and ($env:Path -notlike "*$path*")) {
        $env:Path = "$path;$env:Path"
    }
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $miseInit = & mise activate pwsh 2>$null
    if ($miseInit) { Invoke-Expression ($miseInit | Out-String) }
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Set-Alias -Name ghs -Value gh
}

function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }
function gs { git status -s @args }
function gl { git pull --rebase @args }
function gp { git push @args }
function lg { git log --oneline --graph --decorate --all @args }

# ai-harness's ledger CLI is a bash script; Git Bash is its interpreter.
function work {
    $script = Join-Path $HOME '.agents\bin\work'
    if ((Test-Path $script) -and (Get-Command bash -ErrorAction SilentlyContinue)) {
        bash $script @args
    }
    else {
        Write-Warning 'work needs Git Bash and ~/.agents/bin/work'
    }
}

if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
}

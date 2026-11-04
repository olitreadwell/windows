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

if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    Set-Alias -Name sudo -Value gsudo
}

# eza replaces Get-ChildItem for interactive listings. Icons need the Nerd
# Font installed by step 25; without it, drop --icons from these functions.
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    function ls { eza --icons --group-directories-first @args }
    function ll { eza --icons --long --header --git --group-directories-first @args }
    function la { eza --icons --long --header --git --all --group-directories-first @args }
    function lt { eza --icons --tree --level=2 @args }
}
else {
    Set-Alias -Name ls -Value Get-ChildItem -Force
    function ll { Get-ChildItem -Force @args }
    function la { Get-ChildItem -Force @args }
}

# bat reads like cat when piped, so this is safe inside scripts and chains.
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Force
    $env:BAT_THEME = 'TwoDark'
    $env:BAT_STYLE = 'numbers,grid,header-filename'
}

# delta as the git pager, but only when the binary is actually present so a
# failed install does not break every git command.
if (Get-Command delta -ErrorAction SilentlyContinue) {
    $env:GIT_PAGER = 'delta'
    $env:DELTA_FEATURES = 'line-numbers navigate'
}
else {
    Remove-Item Env:GIT_PAGER -ErrorAction SilentlyContinue
}

function touch {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Path)
    foreach ($item in $Path) {
        if (Test-Path -LiteralPath $item) { (Get-Item -LiteralPath $item).LastWriteTime = Get-Date }
        else { New-Item -ItemType File -Path $item -Force | Out-Null }
    }
}

function mkcd {
    param([Parameter(Mandatory = $true)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function which {
    param([Parameter(Mandatory = $true)][string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $command.Source } else { Write-Warning "not found: $Name" }
}

function fcd {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Warning 'fzf is not installed'; return }
    $directory = $null
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $directory = & fd --type d --hidden --exclude .git 2>$null | & fzf --height 40%
    }
    else {
        $directory = Get-ChildItem -Directory -Recurse -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName | & fzf --height 40%
    }
    if ($directory) { Set-Location $directory }
}

function fh {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { Write-Warning 'fzf is not installed'; return }
    if (-not (Get-Command Get-PSReadLineOption -ErrorAction SilentlyContinue)) { return }
    $historyPath = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path $historyPath)) { return }
    $line = Get-Content -LiteralPath $historyPath | Select-Object -Unique | & fzf --height 40% --reverse
    if ($line) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($line) }
}

function update {
    $script = Join-Path $HOME 'bin\update.ps1'
    if (Test-Path $script) { & $script @args }
    else { Write-Warning 'update.ps1 is missing. Re-run: .\bootstrap.ps1 -Only 40-dotfiles' }
}

function wupdate {
    $script = Join-Path $HOME 'bin\diagnose-update.ps1'
    if (Test-Path $script) { & $script @args }
    else { Write-Warning 'diagnose-update.ps1 is missing. Re-run: .\bootstrap.ps1 -Only 40-dotfiles' }
}

function gs { git status -s @args }
function gl { git pull --rebase @args }
function gp { git push @args }
function gd { git diff @args }
function gco { git checkout @args }
function gb { git branch @args }
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

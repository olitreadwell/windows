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
    # The built-in ls alias is AllScope, so -Force cannot rewrite it.
    try {
        Remove-Item -Path Alias:ls -Force -ErrorAction SilentlyContinue
        Set-Alias -Name ls -Value Get-ChildItem
    }
    catch { }
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

function logs {
    $dir = Join-Path $env:LOCALAPPDATA 'oli-windows'
    if (Test-Path $dir) { Invoke-Item $dir }
    else { Write-Warning 'no log directory yet' }
}

function doctor {
    wupdate
    Write-Host ''
    Write-Host 'pending package updates' -ForegroundColor Cyan
    update -DryRun
}

function defaultapps {
    Start-Process 'ms-settings:defaultapps'
}

function caffeinate {
    param([int]$Minutes = 60)
    if (-not ('Win32.Power' -as [type])) {
        Add-Type -Namespace Win32 -Name Power -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
    }
    $continuous = [uint32]2147483648
    $system = [uint32]1
    $display = [uint32]2
    [Win32.Power]::SetThreadExecutionState([uint32]($continuous -bor $system -bor $display)) | Out-Null
    Write-Host ("Awake for {0} minutes. Press Ctrl+C to stop." -f $Minutes)
    try { Start-Sleep -Seconds ($Minutes * 60) }
    finally { [Win32.Power]::SetThreadExecutionState($continuous) | Out-Null }
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

# Codex ships its own completer. Step 50 regenerates the file after each
# install, and Update-All refreshes it after an upgrade.
$codexCompletion = Join-Path $HOME '.codex\completions.ps1'
if (Test-Path $codexCompletion) { . $codexCompletion }

$psfzf = Get-Module -ListAvailable -Name PSFzf | Select-Object -First 1
$psfzfLoaded = $false
if ($psfzf) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    $psfzfLoaded = [bool](Get-Module PSFzf)
}
if ($psfzfLoaded) {
    if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
        Set-PsFzfOption -EnableAliasFuzzyEdit -EnableAliasFuzzyGitStatus -ErrorAction SilentlyContinue
    }
}
elseif ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue)) {
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
        $file = $null
        if (Get-Command fd -ErrorAction SilentlyContinue) {
            $file = & fd --type f --hidden --exclude .git | & fzf --height 40%
        }
        else {
            $file = Get-ChildItem -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName | & fzf --height 40%
        }
        if ($file) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file) }
    }
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
        $historyPath = (Get-PSReadLineOption).HistorySavePath
        if (-not (Test-Path $historyPath)) { return }
        $line = Get-Content -LiteralPath $historyPath | Select-Object -Unique | & fzf --height 40% --reverse
        if ($line) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($line)
        }
    }
}

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}

# Windows PowerShell 5.1 ships PSReadLine 1.2, which has no prediction
# parameters. Binding errors ignore -ErrorAction, so check the parameters.
$psReadLine = Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue
if ($psReadLine) {
    if ($psReadLine.Parameters.ContainsKey('PredictionSource')) {
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    }
    if ($psReadLine.Parameters.ContainsKey('PredictionViewStyle')) {
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    }
    try { Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction Stop }
    catch { }
}

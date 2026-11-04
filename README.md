# Windows

Provisioning system for the Surface Book. Separate repo from
[`laptop`](https://github.com/olitreadwell/laptop), because the machine is a
different platform with a different shell, package manager and failure model.

The first target is the 2017 Surface Book 2 that has sat unused: Windows 10,
no recent updates, no agent tooling. The repo detects that machine instead of
assuming it. `knowledge/hardware.md` lists what the two Surface Book 2 sizes
can be.

## If Windows Update is stuck, start here

Windows 10 22H2 is the last feature update, so a stuck 22H2 install is a
repair problem, not a newer release. Check it with the read-only script
below. It changes nothing and prints the exact error code and next actions:

```powershell
.\scripts\Diagnose-WindowsUpdate.ps1
```

The update step is optional. To install the CLI and agent tooling while
Windows Update is still failing:

```powershell
.\bootstrap.ps1 -SkipUpdates
```

State the trade-off plainly: the machine stays unpatched until Windows Update
works. Read `docs/new-machine-runbook.md` for the security path, then upgrade
to Windows 11 or enrol in ESU.

## Quickstart

The Surface Book may have no git and no winget. Use the ZIP path first; it
needs only PowerShell 5.1 and an internet connection.

Run in an elevated PowerShell window:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zip = Join-Path $env:TEMP 'windows-main.zip'
Invoke-WebRequest -Uri 'https://github.com/olitreadwell/windows/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $HOME -Force
if (Test-Path "$HOME\windows") { Move-Item "$HOME\windows" "$HOME\windows.bak.$(Get-Date -Format 'yyyyMMddHHmmss')" }
Rename-Item "$HOME\windows-main" "$HOME\windows"
Set-Location "$HOME\windows"
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun
```

Then the real run:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

While Windows Update is stuck, use the fast path instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -SkipUpdates
```

If git is already installed, cloning works too:

```powershell
git clone https://github.com/olitreadwell/windows "$HOME\windows"
Set-Location "$HOME\windows"
.\bootstrap.ps1 -DryRun
```

The ZIP copy has no `.git` directory. Re-download the ZIP to update this
repo; the bootstrap still installs git and clones `dotfiles` and
`ai-harness` at step 40.

## Commands

- `.\bootstrap.ps1` provisions the machine, idempotently.
- `.\bootstrap.ps1 -DryRun` prints the plan and exits.
- `.\bootstrap.ps1 -From 40-dotfiles` resumes from a step.
- `.\bootstrap.ps1 -Only 90-verify` runs one step.
- `.\bootstrap.ps1 -SkipUpdates` runs every step except Windows Update.
- `.\bootstrap.ps1 -Yes` skips interactive auth prompts with warnings.
- `.\bootstrap.ps1 -NoAdmin` skips the elevation guard. Admin-only steps will fail.
- `.\scripts\Update-All.ps1` updates winget packages, mise runtimes and `gh` extensions.
- `.\scripts\Diagnose-WindowsUpdate.ps1` reports why an update is stuck, read-only.
- `.\tests\run.ps1` runs the gate on Windows.

After step 40 the same two helpers run as the commands `update` and `wupdate`.

One manual setting: Windows Terminal > Profiles > Defaults > Appearance >
Font face > `JetBrainsMono Nerd Font`. Without it, `eza` icons and the
Starship prompt show as boxes. The bootstrap installs the font but does not
edit Terminal's JSON settings.

## Layout

- `PROMPT.md`: operating prompt for improve and provision modes.
- `bootstrap.ps1`: detect, plan, run, verify.
- `core/`: logging, safety helpers, detection, planning, winget and harness wiring.
- `steps/`: numbered idempotent PowerShell steps.
- `config/`: Windows-native configs and the winget package list.
- `knowledge/`: hardware facts, support dates, migration map, decisions.
- `tests/`: the Windows gate.

## What stage 1 does

1. Records the machine and creates a battery report and restore point.
2. Installs pending security and quality updates without feature upgrades or an automatic reboot.
3. Ensures `winget`, then installs the core CLI tools: `bat`, `eza`, `delta`,
   `fzf`, `zoxide`, `ripgrep`, `fd`, a Nerd Font and `gsudo`.
4. Authenticates `gh`, installs 1Password and configures its SSH agent pipe.
5. Clones `dotfiles` and `ai-harness`, then links the Windows-safe configs.
6. Installs runtimes through `mise`. `fnm` and `bun` are installed only if `mise` fails.
7. Installs Codex CLI and Claude Code. Auth is prompted unless you pass `-Yes`.
8. Installs the GUI apps from `config/packages.txt`.
9. Verifies the result and prints the remaining manual actions.

## Safety

Each step converges on re-run. An overwritten config is copied to
`<path>.bak.<timestamp>` first. The bootstrap never deletes user data and
never reboots automatically.

## Related repos

- [`dotfiles`](https://github.com/olitreadwell/dotfiles): shell, git and editor config.
- [`ai-harness`](https://github.com/olitreadwell/ai-harness): skills and agent wiring.
- [`laptop`](https://github.com/olitreadwell/laptop): macOS provisioning, the source of the step pattern.

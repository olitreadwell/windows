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

A fresh Windows 10 install blocks `.ps1` files with "running scripts is
disabled on this system". Either start the script through
`powershell -ExecutionPolicy Bypass -File ...`, or unlock the current window
only:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
```

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
- `.\bootstrap.ps1 -Only 90-verify` runs one step. Comma lists work: `-Only 40-dotfiles,50-ai-tools`.
- `.\bootstrap.ps1 -Only 26-scoop` prints the Scoop command (run it from a normal window).
- `.\bootstrap.ps1 -SkipUpdates` runs every step except Windows Update and
  pauses updates for 7 days, so a stuck feature install stops retrying.
- `.\bootstrap.ps1 -Parallel` runs `47-pwsh-modules` in a separate window
  while `27-apps` installs. Winget steps stay serial because winget takes a
  global installer lock. `45-runtimes` cannot move earlier: it needs the
  mise config that step 40 links.
- `.\bootstrap.ps1 -OptionalApps` adds the large or situational apps
  (LibreOffice, GIMP, darktable, Mixxx, qBittorrent, Beeper, Jan, Dataflare).
- `.\bootstrap.ps1 -Wsl` enables WSL2 and Ubuntu after a restart.
- `.\bootstrap.ps1 -RepairWindows` runs DISM, SFC and the update cache reset.
- `.\bootstrap.ps1 -FixUpdate` stops the update services, renames the download cache and staging folders, and restarts them. Run it, restart, then upgrade.
- `.\bootstrap.ps1 -EnableSsh` installs the OpenSSH server, adds the repo key, and limits port 22 to Tailscale.
- `.\bootstrap.ps1 -Windows10` downloads Microsoft's Windows 10 Update Assistant and runs the 22H2 upgrade.
- `.\bootstrap.ps1 -Windows11` downloads Microsoft's Installation Assistant and runs the Windows 11 upgrade, bypassing Windows Update.
- `.\bootstrap.ps1 -ScheduleUpdate` registers a weekly Sunday 10:00 update task.
- `.\bootstrap.ps1 -Yes` skips interactive auth prompts with warnings.
- `.\bootstrap.ps1 -NoAdmin` skips the elevation guard. Admin-only steps will fail.
- `.\scripts\Update-All.ps1` updates winget packages, mise runtimes and `gh` extensions.
- `.\scripts\Diagnose-WindowsUpdate.ps1` reports why an update is stuck, read-only.
- `.\scripts\Remove-RecordedApps.ps1` lists what this repo installed; add `-Apply` to uninstall.
- `sendlogs` (or `.\scripts\Send-Logs.ps1`) uploads the recent logs to a secret gist for review.
- `.\tests\run.ps1` runs the gate on Windows.

After step 40 the same two helpers run as the commands `update` and `wupdate`.

One manual setting: Windows Terminal > Profiles > Defaults > Appearance >
Font face > `JetBrainsMono Nerd Font`. Without it, `eza` icons and the
Starship prompt show as boxes. The bootstrap installs the font but does not
edit Terminal's JSON settings.

Windows blocks a scripted default-browser change, so step 60 opens the
Default Apps page and asks you to pick Zen Browser. Reopen it later with
`defaultapps`. Keep the machine awake with `caffeinate 120`, or use the
PowerToys Awake tray menu.

Scoop is the one install the bootstrap cannot finish, because it refuses to
run elevated. In a normal PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
irm get.scoop.sh | iex
scoop bucket add extras
```

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
2. Applies safe Windows settings: long paths, Developer Mode, file
   extensions, full path in the Explorer title, Explorer opening This PC,
   clipboard history, tips off, RemoteSigned execution policy for the
   current user, Defender PUA protection and reversed scroll direction.
3. Enables Remote Desktop over Tailscale, limited to the Tailscale address
   range and the local subnet.
4. Installs pending security and quality updates without feature upgrades or an automatic reboot.
5. Ensures `winget`, then installs the core CLI tools: `bat`, `eza`, `delta`,
   `fzf`, `zoxide`, `ripgrep`, `fd`, `jq`, `ffmpeg`, the cloud and Kubernetes
   CLIs, a Nerd Font and `gsudo`.
6. Installs the GUI apps from `config/packages.txt`, so Zen, Alacritty,
   Tailscale and the rest are proven working before the long steps.
7. Authenticates `gh`, installs 1Password and configures its SSH agent pipe.
8. Clones `dotfiles` and `ai-harness`, then links the Windows-safe configs.
9. Installs runtimes through `mise`. `fnm` and `bun` are installed only if `mise` fails.
10. Installs the PowerShell module bundle: `PSFzf` for fuzzy history and files,
   and `Terminal-Icons` for icons in `Get-ChildItem`.
11. Installs Codex CLI, Claude Code and Ollama, generates Codex tab completion
   and prompts for auth unless you pass `-Yes`.
12. Verifies the result and prints the remaining manual actions.

A full run downloads several GB. The macOS to Windows mapping, including
what is optional and what has no equivalent, is in
`knowledge/windows-equivalents.md`.

## Safety

Each step converges on re-run. An overwritten config is copied to
`<path>.bak.<timestamp>` first. The bootstrap never deletes user data and
never reboots automatically.

## Logs and audit

Every run writes under `%LOCALAPPDATA%\oli-windows`:

- `bootstrap.log`: append-only history across all runs.
- `errors.log`: every ERROR line, so a failure is one file away.
- `logs\<runid>-bootstrap.log`: one file per run, rotated to the last 30.
- `runs\<runid>.json`: plan, per-step status, seconds and the machine facts.

The run summary is written on success and on failure. Open the folder with
`logs` in a new terminal, or run `doctor` for update diagnosis plus pending
package updates.

## Admin prompts

UAC stays on. The bootstrap does not disable it. `gsudo` is installed and
configured to cache one elevated session for 30 minutes, so a burst of admin
commands asks once. `sudo <command>` in a new terminal uses that cache.

## Related repos

- [`dotfiles`](https://github.com/olitreadwell/dotfiles): shell, git and editor config.
- [`ai-harness`](https://github.com/olitreadwell/ai-harness): skills and agent wiring.
- [`laptop`](https://github.com/olitreadwell/laptop): macOS provisioning, the source of the step pattern.

# Windows

Provisioning system for the Surface Book. Separate repo from
[`laptop`](https://github.com/olitreadwell/laptop), because the machine is a
different platform with a different shell, package manager and failure model.

The first target is the 2017 Surface Book 2 that has sat unused: Windows 10,
no recent updates, no agent tooling. The repo detects that machine instead of
assuming it. `knowledge/hardware.md` lists what the two Surface Book 2 sizes
can be.

## Stop before the quickstart

If the machine is on unpatched Windows 10, read
`docs/new-machine-runbook.md` and finish steps 1 to 3 first. Update Windows,
then upgrade to Windows 11 or enrol in ESU. Do not download developer tools
onto an unpatched Windows 10 machine.

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
- `.\bootstrap.ps1 -Yes` skips interactive auth prompts with warnings.
- `.\bootstrap.ps1 -NoAdmin` skips the elevation guard. Admin-only steps will fail.
- `.\tests\run.ps1` runs the gate on Windows.

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
3. Ensures `winget`, then installs the core CLI tools.
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

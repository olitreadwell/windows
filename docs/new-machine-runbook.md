# Surface Book runbook

Do these in order. The bootstrap handles the repeatable parts; this page
covers the decisions and the physical checks.

## 1. Back up if there are files you care about

If the profile is empty, skip this. Otherwise copy it to an external drive:

```powershell
$source = $env:USERPROFILE
$target = Read-Host 'Backup drive and folder, for example D:\surface-book-backup'
robocopy $source $target /E /XJ /R:1 /W:1 /LOG:"$env:TEMP\surface-backup.log"
```

`/XJ` skips junctions so the copy does not loop. Check that `$target` exists
and is the drive you mean before running it.

## 2. Inspect the hardware

- Check for a swollen battery or a deformed case. If either is present, stop
  and replace the battery before leaving it plugged in.
- Keep the charger connected for the whole run.
- Run the battery report after preflight and record the wear.

## 3. Get Windows current before installing tools

An old Windows 10 build may have broken TLS, an old App Installer and no
winget. Run Windows Update manually until it reports no more updates, and
restart when asked. Then decide the support path:

- Upgrade to Windows 11. This machine has an i7-8650U, so it is supported.
- Or enrol in consumer ESU, which runs to 2027-10-12. ESU requires Windows 10
  22H2 with the latest updates and KB5126256, an administrator Microsoft
  account that is not a child account, and a personal device that is not
  kiosk, domain joined, Entra joined or MDM managed.
- Or keep the machine offline.

Do not browse, read email or run agents on an unpatched Windows 10 install.

### If the 22H2 update is stuck

Windows 10 22H2 is the final feature update. A machine stuck installing it is
not missing a newer release; the install itself is failing. Run the
read-only diagnosis first:

```powershell
.\scripts\Diagnose-WindowsUpdate.ps1
```

It reports the build, pending reboot, update services, free space, component
store health, recent update errors and the tail of the setup logs. It changes
nothing.

Then pick one path:

- Repair first: restart, free 20 GB on `C:`, run
  `DISM /Online /Cleanup-Image /RestoreHealth` and `SFC /Scannow`, restart,
  and retry Windows Update. This is the path that ends with a patched
  machine.
- Tooling first: run `.\bootstrap.ps1 -SkipUpdates`. The CLI and agent setup
  completes now and the machine stays unpatched until the repair works.

Tooling first is a deliberate trade-off, not a fix. Do not browse, read email
or run agents on the unpatched install for long.

## 4. Get the repo without git

The machine probably has no git. Download the ZIP instead:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zip = Join-Path $env:TEMP 'windows-main.zip'
Invoke-WebRequest -Uri 'https://github.com/olitreadwell/windows/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $HOME -Force
if (Test-Path "$HOME\windows") { Move-Item "$HOME\windows" "$HOME\windows.bak.$(Get-Date -Format 'yyyyMMddHHmmss')" }
Rename-Item "$HOME\windows-main" "$HOME\windows"
Set-Location "$HOME\windows"
```

If git is already installed, this works too:

```powershell
git clone https://github.com/olitreadwell/windows "$HOME\windows"
```

The bootstrap installs Git for Windows at step 25, then clones `dotfiles`
and `ai-harness` at step 40. A ZIP copy has no `.git`, so update it by
downloading the ZIP again.

## 5. Preview the plan

Open PowerShell as Administrator, then:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\bootstrap.ps1 -DryRun
```

The default execution policy on a fresh Windows 10 install refuses to run
`.ps1` files. `Process` scope lasts for this window only.

Read the step list. The first run starts at `10-preflight`.

## 6. Run it

```powershell
.\bootstrap.ps1
```

If Windows Update is still failing, run the fast path instead:

```powershell
.\bootstrap.ps1 -SkipUpdates
```

This skips only step `15-updates`. Everything else runs, including `winget`,
Git, the CLI tools, the agent CLIs and the repo clones.

Expect one or two restarts for Windows updates. After each restart, resume
with:

```powershell
.\bootstrap.ps1 -From 15-updates
```

Repeat until it reports no pending updates, then continue with
`.\bootstrap.ps1 -From 20-winget`.

## 7. Finish the human steps

- Sign in to 1Password, then enable Settings > Developer > SSH agent.
- Set `OLLAMA_CLOUD_MAX_API_KEY` for Codex if it was not entered during step
  50. Get the key from 1Password on the Mac.
- Run `gh auth status` and `claude auth login`.
- On an unpatched Windows 10 install the default browser may be the old
  EdgeHTML build, which cannot render the GitHub device page. Set Zen or
  Chrome as the default first, or open `https://github.com/login/device`
  in that browser and type the code that `gh auth login --web` prints.
- Open a new PowerShell 7 window and check `starship --version` and
  `mise ls`.
- Set Windows Terminal > Profiles > Defaults > Appearance > Font face to
  `JetBrainsMono Nerd Font`. The bootstrap installs the font but leaves the
  Terminal JSON file alone.
- Restart once more so PATH changes reach every app.

## 8. Record the machine

Copy the non-identifying values into `knowledge/current-machine.md` and
commit them. Keep the serial number in local state only. This repo is public.

## If something fails

The failing step prints a resume command. The full log is at
`%LOCALAPPDATA%\oli-windows\bootstrap.log`. Failures also go to
`errors.log`, and each run leaves `runs\<runid>.json` with per-step status
and timing. Open the folder with:

```powershell
Invoke-Item "$env:LOCALAPPDATA\oli-windows"
```

Do not delete the machine state directory; it holds the preflight facts and
the battery report.

# Surface Book runbook

Do these in order. The bootstrap handles the repeatable parts; this page
covers the decisions and the physical checks.

## 1. Back up before touching anything

Copy the user profile to an external drive or OneDrive. The bootstrap does
not delete data, but a 2017 machine may have a failing drive.

```powershell
$source = $env:USERPROFILE
$target = 'E:\surface-book-backup'
robocopy $source $target /E /XJ /R:1 /W:1 /LOG:"$env:TEMP\surface-backup.log"
```

`/XJ` skips junctions so the copy does not loop. Read the summary at the end
of the log.

## 2. Inspect the hardware

- Check for a swollen battery or a deformed case. If either is present, stop
  and replace the battery before leaving it plugged in.
- Keep the charger connected for the whole run.
- Run the battery report after preflight and record the wear.

## 3. Get Windows current before installing tools

An old Windows 10 build may have broken TLS, an old App Installer and no
winget. Run Windows Update manually until it reports no more updates, and
restart when asked. Then decide the support path:

- Enrol in consumer ESU, which runs to 2027-10-12.
- Or upgrade to Windows 11 if the CPU is 8th generation or newer.
- Or keep the machine offline.

Do not browse, read email or run agents on an unpatched Windows 10 install.

## 4. Clone the repo

```powershell
git clone https://github.com/olitreadwell/windows "$HOME\windows"
Set-Location "$HOME\windows"
```

If `git` is missing, install Git for Windows from
<https://git-scm.com/download/win>.

## 5. Preview the plan

Open PowerShell as Administrator, then:

```powershell
.\bootstrap.ps1 -DryRun
```

Read the step list. The first run starts at `10-preflight`.

## 6. Run it

```powershell
.\bootstrap.ps1
```

Expect one or two restarts for Windows updates. Resume with:

```powershell
.\bootstrap.ps1 -From 20-winget
```

## 7. Finish the human steps

- Sign in to 1Password, then enable Settings > Developer > SSH agent.
- Run `gh auth status`, `codex login`, `claude auth login`.
- Open a new PowerShell 7 window and check `starship --version` and
  `mise ls`.
- Restart once more so PATH changes reach every app.

## 8. Record the machine

Copy the real values into `knowledge/current-machine.md` and commit them.
This is what a future agent reads before changing the plan.

## If something fails

The failing step prints a resume command. The full log is at
`%LOCALAPPDATA%\oli-windows\bootstrap.log`. Do not delete the machine state
directory; it holds the preflight facts and the battery report.

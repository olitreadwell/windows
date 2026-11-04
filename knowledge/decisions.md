# Decisions

Architecture decisions in ADR form. Add one before adopting a change that is
hard to reverse.

## ADR 1: Separate repo, not a branch or fork

Status: accepted, 2026-11-05.

The Windows system shares almost no executable code with `laptop`. The macOS
repo is bash, Homebrew, `defaults` and `launchd`; the Windows repo is
PowerShell, winget, registry and Scheduled Tasks. A `windows` branch would
fork every step, break the macOS gate on main, and force both loops to share
one history. A fork has the same drift problem and cannot be private in the
same way.

Decision: `olitreadwell/windows` is a separate private repo. It keeps the
step pattern and links to `laptop`, `dotfiles` and `ai-harness` as upstream
sources.

## ADR 2: PowerShell 5.1 at the entry point

Status: accepted, 2026-11-05.

The target machine may not have PowerShell 7. `bootstrap.ps1` and every file
it loads before `pwsh` is installed must run on Windows PowerShell 5.1.

Decision: no ternary operator, no null-coalescing, no `-Parallel`, no
PowerShell 7-only modules in the pre-`pwsh` path. Later steps may use 7 once
it exists.

## ADR 3: winget is the package manager

Status: accepted, 2026-11-05.

The alternatives were Chocolatey, Scoop and manual downloads. winget ships
with modern Windows 10 through App Installer, has a large package set and
needs no third-party bootstrap service. It is missing on old builds, but the
bootstrap installs App Installer from the official URL.

Decision: winget primary. Add a package only after checking its exact ID in
`microsoft/winget-pkgs`. Record failures instead of silently falling back to
a script piped from the internet.

## ADR 4: Junction and hard link before copy

Status: accepted, 2026-11-05.

Windows symlinks need Developer Mode or admin. Junctions need neither and
work for directories. Hard links need neither and work for files on the same
volume.

Decision: directories use junctions, files use hard links, symlink is the
second attempt, copy is the final fallback. Every fallback is logged.

## ADR 5: Windows configs live here

Status: accepted, 2026-11-05.

`dotfiles` is a macOS-shaped repo. Adding Windows-specific files there would
force the macOS installer to know about paths it never uses.

Decision: portable files come from `dotfiles`. Windows-specific files live in
`config/` here. Revisit once the Windows set is stable enough to upstream.

## ADR 6: No automatic reboot or ESU enrolment

Status: accepted, 2026-11-05.

Windows updates and ESU enrolment need human decisions: a reboot can lose
work, and ESU needs a Microsoft account and a payment or rewards choice.

Decision: the bootstrap installs updates with `-IgnoreReboot`, reports that a
restart is needed, and leaves ESU enrolment to the runbook. It never reboots
and never claims the machine is supported.

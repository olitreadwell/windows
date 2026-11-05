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

Decision: `olitreadwell/windows` is a separate public repo. Private-repo
GitHub Actions is blocked by the account billing state, and the content has
no secrets. It keeps the step pattern and links to `laptop`, `dotfiles` and
`ai-harness` as upstream sources.

## ADR 2: PowerShell 5.1 at the entry point

Status: accepted, 2026-11-05.

The target machine may not have PowerShell 7. `bootstrap.ps1` and every file
it loads before `pwsh` is installed must run on Windows PowerShell 5.1.

Decision: no ternary operator, no null-coalescing, no `-Parallel`, no
PowerShell 7-only modules. The runner never relaunches under `pwsh`, so every
step runs in the 5.1 host.

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

Decision: the bootstrap installs security and quality updates with
`-IgnoreReboot`, excludes `Upgrades` and `Feature Packs`, stops when a
restart is pending, and leaves ESU enrolment and the Windows 11 upgrade to
the runbook. It never reboots and never claims hardware eligibility.

## ADR 7: Non-winget tools are explicit exceptions

Status: accepted, 2026-11-05.

Three installs cannot come from winget: the Windows Update PowerShell module
(`PSWindowsUpdate` from PSGallery), the App Installer bootstrap needed to get
winget on an old build, and runtime versions managed by `mise`. These are
toolchain exceptions, not package installs.

Decision: they stay explicit and logged. Do not add another non-winget
installer without an ADR.

## ADR 8: Windows Update is skippable, never silent

Status: accepted, 2026-11-05.

The Surface Book is stuck on the Windows 10 22H2 install. Waiting for a
repair blocks every useful tool behind one failing step. Hiding the failure
would be worse: an unpatched Windows 10 machine that looks provisioned is a
security trap.

Decision: `bootstrap.ps1 -SkipUpdates` removes only step `15-updates` and
prints a warning on every run. `scripts/Diagnose-WindowsUpdate.ps1` reports
the cause without changing anything. The docs state the trade-off, and the
runbook keeps repair and ESU as the preferred path. The default run still
installs updates and still refuses feature upgrades.

## ADR 9: Interactive pager and listing tools fail soft

Status: accepted, 2026-11-05.

`bat`, `eza` and `delta` are core packages, but a failed winget install must
not break the shell or every git command. A static `core.pager = delta` in
the git config would do exactly that.

Decision: the profile checks for each binary before aliasing it. `GIT_PAGER`
is set to `delta` only when the binary exists, otherwise to `less -R`. Git
config holds only the delta display settings, which are inert when delta is
missing.

## ADR 10: Two PSGallery modules are allowed

Status: accepted, 2026-11-05.

Windows has no oh-my-zsh bundle. The plugin behaviours worth having are
already separate: Starship for the prompt, PSReadLine for autosuggestions,
fzf for history and files. Two behaviours still need a module:
`PSFzf` for the standard `Ctrl+R` and `Ctrl+T` chords with previews, and
`Terminal-Icons` for file icons in `Get-ChildItem`.

Decision: step `47-pwsh-modules` installs those two from PSGallery into the
current user scope. The step is non-fatal. The profile keeps its own fzf key
bindings as a fallback when `PSFzf` is absent, so a failed module install
degrades instead of breaking the shell. No other module joins the list
without an ADR.

## ADR 11: Settings stay reversible, UAC stays on

Status: accepted, 2026-11-05.

UAC prompts are annoying, and the tempting fix is to disable UAC or enable
the built-in Administrator account. Both widen the blast radius of every
mistake and every malicious script, and neither is needed for a smooth
setup.

Decision: step `12-settings` changes only long paths, Developer Mode and two
Explorer display values. Each is read before it is written, so a second run
changes nothing. `gsudo` gets a 30 minute elevation cache for the current
user. UAC stays on and no account is enabled or elevated.

Later additions stay reversible: clipboard history, Explorer opening This
PC, tips off, Defender PUA protection and a `RemoteSigned` execution policy
for the current user. `RemoteSigned` is a deliberate step down from
`Restricted`: local scripts run, downloaded scripts still need a signature.
The bootstrap does not change the machine-wide policy, and it does not
disable UAC.

## ADR 12: Scoop is a printed instruction, not a silent script

Status: accepted, 2026-11-05.

Scoop is useful for unix-style CLI packages that winget lacks. Its installer
refuses to run as administrator, and the bootstrap always runs elevated.
Installing it globally with `-RunAsAdmin` would make every later `scoop
install` need admin, which is worse than one manual step.

Decision: step `26-scoop` checks for an existing install and otherwise
prints the exact three commands for a normal PowerShell window. The repo
does not pipe a remote script into `iex` from an elevated process. When run
from a normal window with `-Only 26-scoop`, the step downloads the installer
to a file, logs its SHA256 and runs it.

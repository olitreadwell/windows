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

## ADR 13: Default browser is a human choice

Status: accepted, 2026-11-05.

Windows 10 validates the default-browser choice with a hash in
`Explorer\FileExts\.html\UserChoice`. A scripted ProgId without that hash is
ignored, and third-party tools that forge the hash break on the next
Windows change. Hiding that behind a script is worse than one manual pick.

Decision: step `27-apps` reads the recorded ProgId, reports the current
browser, and opens the Default Apps page when it is not Zen. It never writes
`UserChoice`. The profile offers `defaultapps` to reopen the page.

## ADR 14: RDP is allowed only over Tailscale

Status: accepted, 2026-11-05.

Remote access from the Mac needs a host that is already in Windows Pro. RDP
is built in and faster than a third-party relay. Opening port 3389 to the
internet would be a serious mistake on an unpatched Windows 10 install.

Decision: step `14-remote` enables RDP with Network Level Authentication and
sets the Remote Desktop firewall rules to `100.64.0.0/10` plus
`LocalSubnet`. Tailscale is the transport. RustDesk stays a manual install
because it is not in winget, and Headscale is not installed because it is a
server, not a client.

## ADR 15: Repair, WSL and scheduling are opt-in

Status: accepted, 2026-11-05.

Three operations are useful but too invasive to run by default: the Windows
Update repair renames system folders and takes 30 minutes, WSL2 needs a
reboot and conflicts with some hypervisors, and a scheduled task changes
machine behaviour after the run ends.

Decision: steps `13-repair`, `21-wsl` and `70-scheduled-update` are always in
the plan but return immediately unless `-RepairWindows`, `-Wsl` or
`-ScheduleUpdate` is passed. Their state checks make a second run a no-op.

## ADR 16: Windows 11 upgrade runs from the Installation Assistant

Status: accepted, 2026-11-05.

The Surface Book 2 has had a 22H2 feature update stuck at 25 percent for
hours, so Windows Update is not a reliable upgrade path on this machine. The
i7-8650U is on Microsoft's supported CPU list and the machine has TPM 2.0 and
Secure Boot, so Windows 11 is a supported destination.

Decision: step `16-win11` is opt-in behind `-Windows11`. It refuses to run when
TPM 2.0, Secure Boot, 25 GB free disk or a clean reboot state is missing. It
downloads Microsoft's Installation Assistant, checks the Authenticode
signature, and starts it. The script never reboots by itself and never enrols
the machine in ESU. `15-updates` still refuses to install feature upgrades.

Manual fallback, documented in the step output: the ISO from
`https://www.microsoft.com/software-download/windows11`, mounted and run as
`setup.exe`. The Media Creation Tool plus an 8 GB USB stick is the clean
install path.

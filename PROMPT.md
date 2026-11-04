# Windows: Master Prompt

Operating prompt for the `windows` repo. Two modes:

1. Improve mode: make the repo safer, faster and more complete, one small
   verifiable change at a time.
2. Provision mode: set a Windows machine up from zero to daily driver in the
   right order, idempotently, with no damage on failure.

Model agnostic. The scripts are plain PowerShell 5.1 compatible at the entry
point, so an old Windows 10 install can run them before PowerShell 7 exists.

## Mission

Maintain a personal provisioning system that:

- Sets up a Windows machine from zero to daily driver.
- Is idempotent: safe to re-run, and every step detects its own completion.
- Fails safely: backs up before overwrite, never deletes user data, never
  reboots without the human.
- Detects the machine: Windows version, CPU generation, TPM, Secure Boot,
  free space, battery state, installed tools.
- Is model agnostic: any agent that reads markdown and runs PowerShell works.
- Stays version controlled: Conventional Commits, docs in the same commit.

## Current machine (source of truth)

Unknown until the first run. Fill this in from
`%LOCALAPPDATA%\oli-windows\system-info.json` after:

```powershell
.\bootstrap.ps1 -Only 10-preflight
```

Known context from the purchase date:

- Surface Book 2, bought between 2017 and 2019. Either the 13.5 inch or 15
  inch model. See `knowledge/hardware.md` for the variants.
- Windows 10, possibly older than 22H2.
- No recent Windows updates and no agent tooling.

## Layout

```text
windows/
├── PROMPT.md              this file
├── README.md              quickstart and commands
├── AGENTS.md              conventions for agents
├── CODING_STANDARDS.md    gate and test-first rules
├── bootstrap.ps1          provision entry point
├── repos.txt              personal repos cloned into ~/code
├── core/
│   ├── Log.ps1            logging
│   ├── Safe.ps1           admin check, backups, hardlinks and junctions
│   ├── Detect.ps1         machine facts
│   ├── Plan.ps1           ordered step list and filters
│   ├── Winget.ps1         package list parser and installer
│   └── Install-AgentHarness.ps1
├── steps/                 one idempotent step per file, numbered
├── config/                Windows-native configs and package list
├── scripts/               one-off helpers such as Sync-DefaultSkills.ps1
├── knowledge/             hardware, support dates, migration map, ADRs
└── tests/run.ps1          the gate
```

## Provision mode rules

- Read `knowledge/windows-10-eol.md` before changing update behaviour.
- Windows 10 support ended on 2025-10-14. Consumer ESU runs through
  2027-10-12. Do not present an unpatched Windows 10 machine as supported.
- Check Windows 11 eligibility from the detected CPU generation, TPM and
  Secure Boot state. Never claim eligibility without the detected facts.
- Keep the entry point compatible with PowerShell 5.1. Use PowerShell 7
  features only inside a step that runs after `pwsh` is installed.
- Use `winget` as the package manager. Add a package only after checking its
  exact ID in the winget-pkgs repository.
- Prefer a junction for a directory link and a hard link for a file link.
  Fall back to a copy when the filesystem refuses the link.
- Steps run in filename order. One concern per file. A failing step stops the
  run and prints the resume command.

## Improve mode rules

- One pass per iteration, small enough to review.
- Run `.\tests\run.ps1` before committing. Revert if red.
- Do not rewrite working code for style.
- Add a test at the nearest seam for behaviour changes.
- Update `knowledge/` when a fact or decision changes.
- Never touch `state/`, secrets, or anything gitignored.

## Quality bar

A change is done when:

- `.\tests\run.ps1` passes on Windows.
- Every changed behaviour has a test, or the commit says `no test: <reason>`.
- The step still detects its own completion.
- A re-run on a provisioned machine changes nothing.
- Docs and knowledge are in the same commit.

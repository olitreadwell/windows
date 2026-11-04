# Agent Instructions (windows)

<!-- coding-standards:begin -->
Project coding rules: `CODING_STANDARDS.md`. Global baseline:
`~/.agents/standards/CODING_STANDARDS.md`. Read both before changing
behaviour.
<!-- coding-standards:end -->

This repo provisions the Surface Book and improves itself. Read `PROMPT.md`
first. It defines the two modes and the quality bar.

## Conventions

- Steps are numbered PowerShell files in `steps/`; one concern per file.
  Order equals filename order.
- Every step starts with `Set-StrictMode -Version 2.0`, uses the helpers
  from `core/`, detects its own completion from system state, logs start and
  end, and never deletes user data.
- The entry point and every file it loads before `pwsh` exists must run on
  PowerShell 5.1. No ternaries, no null-coalescing, no `ForEach-Object
  -Parallel`.
- Names are 2 or 3 words and domain prefixed: `Install-WingetPackage`,
  `Get-MachineInfo`, `Set-ManagedFile`.
- A directory link is a junction. A file link is a hard link. A copy is the
  fallback, and it is logged.
- Knowledge lives in `knowledge/`. Decisions go in `knowledge/decisions.md`
  as ADRs before adoption.
- Commits use Conventional Commits: `feat`, `fix`, `chore`, `docs`, `test`,
  `refactor`, `ci`.

## Rules for the loop

- One pass per iteration.
- Never touch secrets, `state/`, or anything gitignored.
- Never rewrite working code for style.
- Always run `.\tests\run.ps1` before committing; revert if red.
- Keep docs in sync in the same commit.

## Testing

`.\tests\run.ps1` parses every PowerShell file, checks the required files,
runs detection and planning, and checks the package list. CI runs the same
gate on `windows-latest` plus PSScriptAnalyzer at error severity.

The gate needs Windows. A macOS machine cannot run it; push and let CI prove
the change.

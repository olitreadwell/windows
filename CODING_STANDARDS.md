<!-- generated-by: coding-standards ensure -->
# Coding standards: windows

Project rules for this repo. The global baseline is
`~/.agents/standards/CODING_STANDARDS.md` and applies unless this file adds a
stricter rule. Read `AGENTS.md` for layout and scope.

## Stack

- Language: PowerShell, 5.1 compatible at the entry point
- Package manager: winget
- Test tools: the repo gate in `tests/run.ps1`

## Commands

- Full gate: `.\tests\run.ps1`
- Run only on Windows. CI uses a `windows-latest` runner.

## Test-first in this repo

- Start with a failing test at the nearest seam. Name the seam in one line
  before writing it.
- Watch the test fail for the right reason, then write the least code that
  passes it.
- Run the full gate before claiming done.
- No test needed for docs, package additions, or one-off data fixes. Say
  `no test: <reason>` in the change.
- Never skip, delete or weaken a test, assertion, type check or lint rule to
  reach green.

## Conventions

- Every step is idempotent and detects completion from system state.
- Use `Set-ManagedFile` and `Set-ManagedDirectory`; do not hand-roll links.
- Back up before overwrite.
- Prefer a positive instruction over a prohibition in agent-facing docs.
- One spelling per concept across the repo.
- Comments explain why, directly above the code they explain.

## Branch names

`<type>/<domain>/<kebab-description>/<issue-id>`. Omit the trailing id when
no issue exists.

## Done when

`.\tests\run.ps1` passes on Windows and every changed behaviour has a test,
or a one-line reason it has none.

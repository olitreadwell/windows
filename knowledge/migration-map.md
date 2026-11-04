# Migration map: macOS repos to Windows

Where each piece of the current setup goes. Status values:

- **Ported**: runs on Windows now.
- **Adapted**: same intent, different mechanism.
- **Deferred**: designed for, not built yet.
- **Dropped**: macOS only, no Windows equivalent worth carrying.

## `laptop` steps

| macOS step | Windows equivalent | Status |
| --- | --- | --- |
| `10-prereqs` Xcode CLT and sudo | `10-preflight` admin check, restore point, battery report | Adapted |
| `15-rosetta-arm64` | none | Dropped |
| `20-homebrew` | `20-winget` and `25-core-tools` | Adapted |
| `30-1password` | `35-1password` plus SSH agent pipe | Adapted |
| `40-dotfiles` | `40-dotfiles` | Adapted |
| `42-codex-config` | `40-dotfiles` and `config/codex/` | Adapted |
| `45-repos` | `65-repos` | Ported |
| `50-shell` zsh and oh-my-zsh | PowerShell profile, Starship, PSReadLine | Adapted |
| `55-macos-settings` | none yet | Deferred |
| `60-runtimes` mise | `45-runtimes` mise. uv is core; fnm and bun are fallbacks only if mise fails | Adapted |
| `70-apps` mas | `60-apps` winget | Adapted |
| `75-apps-config` plist restore | none yet | Deferred |
| `76-manual-apps` DMG installs | none yet | Deferred |
| `80-auth` gh, claude, codex | `30-auth` and `50-ai-tools` | Ported |
| `85-automation-macos` LaunchAgents | Windows Scheduled Tasks | Deferred |
| `90-verify` | `90-verify` | Ported |
| `loop/` self-improvement daemon | same idea, not built | Deferred |

The step pattern carries over: numbered files, one concern, idempotent,
resumable with `-From`.

## `dotfiles`

| macOS file | Windows handling | Status |
| --- | --- | --- |
| `dot_zshrc`, `dot_zprofile`, aliases | `config/profile/Microsoft.PowerShell_profile.ps1` | Adapted |
| oh-my-zsh, zsh plugins | Starship, PSReadLine, zoxide, fzf | Adapted |
| `dot_gitconfig` | `config/gitconfig.txt`, autocrlf and credential manager added | Adapted |
| `git_hooks/` | junction at `~/.config/git/hooks`, runs through Git for Windows | Ported |
| `gitmessage` | `~/.gitmessage` | Ported |
| `dot_gitignore_global` | `~/.gitignore_global` | Ported |
| `dot_config/mise/config.toml` | `config/mise.toml`; Ruby and shellcheck dropped | Adapted |
| `dot_config/starship.dark.toml` | `config/starship.toml` | Ported |
| `dot_config/gh/config.yml` | copied to `~/.config/gh/config.yml` | Ported |
| `dot_codex/private_config.toml` | `config/codex/config.toml`, macOS notify path removed | Adapted |
| `dot_codex/rules/default.rules` | `config/codex/rules/default.rules` | Ported |
| `dot_claude/statusline.sh` | not ported | Deferred |
| `bin/` git helpers | not ported; they are bash | Deferred |
| `bin/executable_gmail-*` | not ported; bash plus macOS keychain | Dropped |
| GPG signing key | not ported; use SSH signing later | Deferred |
| 1Password SSH agent socket | named pipe `//./pipe/openssh-ssh-agent` | Adapted |

The dotfiles repo stays the source of truth for the files that are portable.
Windows-specific files live in this repo so the macOS install is not forced
to understand Windows paths.

## `ai-harness`

| Piece | Windows handling | Status |
| --- | --- | --- |
| `skills/*` | directory junctions into `.claude/skills`, `.codex/skills` and other detected tools | Adapted |
| `agents/*.toml` | hard links into `~/.codex/agents` | Ported |
| `AGENTS.md` | hard link to `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` | Ported |
| `install.sh` | `core/Install-AgentHarness.ps1` lives here until upstreamed | Adapted |
| `bin/work` ledger CLI | bash script; PowerShell wrapper needs Git Bash | Deferred |
| `scripts/*.py` | Python 3 plus `uv`; not wired yet | Deferred |
| standing caveman and ADHD style | `scripts/Sync-DefaultSkills.ps1` | Ported |

The harness installer is the strongest candidate to move upstream into
`ai-harness` once the Windows port settles.

## macOS-only pieces

- Homebrew, casks, `mas`, LaunchAgents, `defaults`, `plutil`.
- iCloud Drive paths for `oli` and `career`.
- iTerm2, Ghostty, Hammerspoon, Raycast, Rectangle.
- Gmail local sync and scheduling scripts.
- Apple Keychain and Touch ID.

## Known gaps

1. No Windows settings step yet.
2. No scheduled update task yet.
3. No `codex` rule sync for the standing style beyond the config block.
4. Native Codex on Windows may still prefer WSL. Verify with `codex --version`
   and a small `codex exec` run before relying on it.
5. The model catalog is 217 KB, too large to carry in agent context, so it
   is fetched from the public `laptop` repo at provision time.
6. The Codex command rules do not cover every Windows destructive command or
   every force-push flag order. Treat them as a guard, not a sandbox.

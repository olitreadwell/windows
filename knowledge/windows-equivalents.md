# macOS to Windows tool map

Mapped from the macOS `Brewfile` in `olitreadwell/laptop`. "Installed" means
`config/packages.txt` or a step installs it. "Optional" means the winget ID
is valid but the package is heavy or situational, so it is not in the
default run.

## Shell and terminal

| macOS | Windows | Status |
| --- | --- | --- |
| iTerm2 | Windows Terminal | installed |
| zsh | PowerShell 7 | installed |
| Oh My Zsh | Starship + PSReadLine + PSFzf + profile aliases | installed |
| starship | Starship | installed |
| zoxide | zoxide | installed |
| fzf | fzf, `Ctrl+R` and `Ctrl+T` | installed |
| eza, ls colours | eza | installed |
| bat | bat | installed |
| delta | delta | installed |
| ripgrep | ripgrep | installed |
| fd | fd | installed |
| tree | `eza --tree` | covered |
| jq | jq | installed |
| gum | none packaged | optional |
| watchman | none | not replaced |
| the_silver_searcher | ripgrep | covered |
| coreutils | Git for Windows plus PowerShell built-ins | covered |
| OpenSSL | ships with Git for Windows | covered |

`gum` has no winget package. The Windows binary is on the Charmbracelet
GitHub releases page. It is not installed because nothing in this repo
needs it.

## Development

| macOS | Windows | Status |
| --- | --- | --- |
| git | Git for Windows | installed |
| gh | GitHub CLI | installed |
| gnupg | GnuPG | installed |
| git-filter-repo | `uv tool install git-filter-repo` | optional |
| go, rust, node, python, java | mise | installed |
| terraform | Terraform | installed |
| kubectl | kubectl | installed |
| helm | Helm | installed |
| minikube | minikube | optional |
| awscli | AWS CLI | installed |
| azure-cli | Azure CLI | installed |
| mongosh | MongoDB Shell | installed |
| postgresql@16 | PostgreSQL | optional |
| docker, colima | Docker Desktop with WSL2 | deferred |
| ffmpeg | FFmpeg | installed |
| opencode | opencode | installed |
| pinentry-mac | not needed | n/a |
| mas | not needed | n/a |

Docker Desktop needs WSL2. That is a later decision, so the bootstrap does
not install it.

## Desktop apps

| macOS | Windows | Status |
| --- | --- | --- |
| 1Password | 1Password | installed |
| Chrome, Firefox | Chrome, Firefox | installed |
| Brave | Brave | installed |
| VS Code | VS Code | installed |
| Obsidian | Obsidian | installed |
| Spotify | Spotify | installed |
| Slack | Slack | installed |
| GitHub Desktop | GitHub Desktop | installed |
| Espanso | Espanso | installed |
| Tailscale | Tailscale | installed |
| Raycast | PowerToys Run | installed |
| Rectangle | PowerToys FancyZones | installed |
| KeepingYouAwake | PowerToys Awake | installed |
| Hammerspoon | PowerToys Keyboard Manager | covered for remaps |
| iina | VLC (`VideoLAN.VLC`) | optional |
| NetNewsWire | Fluent Reader | optional |
| imageoptim | Squoosh in the browser | not replaced |
| LuLu | Windows Firewall | not replaced |
| Airflow, IINA cast | none | not replaced |

## Adding an optional package

Check the exact ID first, then install it once:

```powershell
winget search <name>
winget install --id <Publisher.Package> --accept-package-agreements --accept-source-agreements
```

Add it to `config/packages.txt` only if a fresh machine should get it.
PSScriptAnalyzer and the repo gate do not check that a winget ID still
exists, so verify it in `microsoft/winget-pkgs` before committing.

## Recommended extras already in the default run

These are Windows-first tools that have no macOS counterpart in the
`Brewfile`, but are the ones Windows power users install first.

### CLI

| Tool | winget ID | Why |
| --- | --- | --- |
| lazygit | `JesseDuffield.lazygit` | TUI git client, staging and rebase without typing |
| yazi | `sxyazi.yazi` | TUI file manager with previews |
| just | `Casey.Just` | Task runner, the `make` replacement for projects |
| direnv | `direnv.direnv` | Per-directory environment variables, pairs with mise |
| xh | `ducaale.xh` | Fast HTTP client, friendlier than curl |
| difftastic | `Wilfred.difftastic` | Syntax-aware structural diff |
| ruff | `astral-sh.ruff` | Python lint and format, pairs with uv |
| bottom | `Clement.bottom` | btop-style CPU, memory and network monitor |
| hyperfine | `sharkdp.hyperfine` | Command benchmarking with warmup |

### Desktop

| Tool | winget ID | Why |
| --- | --- | --- |
| Everything | `voidtools.Everything` | Instant filename search over every drive |
| ShareX | `ShareX.ShareX` | Screenshots, screen recording, upload targets |
| PowerToys | `Microsoft.PowerToys` | FancyZones, Run, Awake, Keyboard Manager, Text Extractor |
| AutoHotkey | `AutoHotkey.AutoHotkey` | Hammerspoon-style keyboard and window scripting |
| Everything and WizTree | `AntibodySoftware.WizTree` | Disk space map when the SSD fills |
| WinMerge | `WinMerge.WinMerge` | Folder and file diff with a GUI |
| CrystalDiskInfo | `CrystalDewWorld.CrystalDiskInfo` | SSD health and temperature on old hardware |
| VLC | `VideoLAN.VLC` | Plays every codec |
| Fluent Reader | `yang991178.fluent-reader` | RSS reader, the NetNewsWire stand-in |
| QuickLook | `QL-Win.QuickLook` | Spacebar file preview, like Finder |
| Zen Browser | `Zen-Team.Zen-Browser` | Firefox-based browser with vertical tabs |
| Zed | `ZedIndustries.Zed` | Fast GPU editor with Windows builds |
| Files | `FilesCommunity.Files` | Tabbed Explorer replacement |
| Nilesoft Shell | `Nilesoft.Shell` | Right-click menu with the classic layout |
| NanaZip | `M2Team.NanaZip` | 7-Zip fork with a modern menu |
| EarTrumpet | `File-New-Project.EarTrumpet` | Per-app volume control |
| LibreOffice | `TheDocumentFoundation.LibreOffice` | Office suite |
| GIMP | `GIMP.GIMP` | Image editor |
| darktable | `darktable.darktable` | RAW photo workflow |
| qBittorrent | `qBittorrent.qBittorrent` | Torrent client |
| Alacritty | `Alacritty.Alacritty` | GPU terminal, alternative to Windows Terminal |
| Mixxx | `Mixxx.Mixxx` | DJ software |
| Wox | `Wox.Wox` | Keyboard launcher |
| Dataflare | `Dataflare.Dataflare` | Database client |
| Beeper | `Beeper.Beeper` | One inbox for chat networks |
| Jan | `Jan.Jan` | Local model desktop client |
| Bitwarden | `Bitwarden.Bitwarden` | Password manager |
| KeePassXC | `KeePassXCTeam.KeePassXC` | Offline password manager, optional |

Considered and not installed: WSL2 (`Microsoft.WSL`, deferred), GlazeWM
(`glzr-io.glazewm`, conflicts with FancyZones), Flow Launcher
(`Flow-Launcher.Flow-Launcher`, PowerToys Run covers it), Syncthing (sync
deletions need a deliberate setup), Deskflow and LocalSend (LAN sharing
needs a firewall decision).

No winget package found: Equicord (a Discord client mod, install from its
own site), Orca (the macOS agent IDE), Paseo, and Scoop (install script, see
the README).

Optional, not installed: DBeaver (`DBeaver.DBeaver`) for database GUIs,
Docker Desktop (needs WSL2), minikube and PostgreSQL 16.

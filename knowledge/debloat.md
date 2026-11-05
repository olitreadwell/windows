# Debloat and telemetry

## What this repo does

Step `12-settings` sets 14 privacy registry values. Nothing is uninstalled,
and every value can be reverted.

- Diagnostic data capped at Security (`AllowTelemetry = 0`).
- Advertising ID off.
- Tailored experiences and sync provider notifications off.
- Silent app installs, OEM preinstalled apps and suggested content off.
- Bing web results in Start search off, Cortana off.
- Activity history publish and upload off.

These are the safe subset. They do not touch Edge, WebView2, Store or the
Windows Update stack.

## Third-party tools

| Tool | Licence | What it does | Risk |
| --- | --- | --- | --- |
| Winutil (Chris Titus) | MIT | Large PowerShell menu: tweaks, app removal, update control | Removes Edge and Store if you pick those options; breaks 1Password and other WebView2 apps |
| O&O ShutUp10++ | Freeware | GUI privacy and telemetry toggles with a restore point | Closed source |
| WPD | Open source | Portable telemetry and firewall blocking | Aggressive host blocking can break Store and updates |
| Sophia Script | MIT | Very broad Windows 10/11 tweak set | Hard to reverse without its preset system |
| Win11Debloat (Raphire) | MIT | PowerShell app removal and tweaks | Written for Windows 11; app removal is permanent |

## Rules for this machine

- Do not remove Edge or the Edge WebView2 runtime. 1Password, Beeper, Jan
  and several installers need WebView2.
- Do not remove the Store or App Installer. Winget depends on App Installer.
- Do not run a debloater while Windows Update is mid-install.
- Take the restore point that step `10-preflight` creates before running any
  third-party debloater.

The registry set in step 12 already covers the visible ads and telemetry
toggles. A third-party tool is only worth it if you want app removal.

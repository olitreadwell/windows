# Current machine

Filled in from the known facts and the first preflight run. The raw facts
live outside git at `%LOCALAPPDATA%\oli-windows\system-info.json`.

Do not commit the serial number. This repo is public.

Run this on the Windows machine:

```powershell
.\bootstrap.ps1 -Only 10-preflight
Get-Content "$env:LOCALAPPDATA\oli-windows\system-info.json"
```

Then replace the placeholders below.

## Identity

- Model: Surface Book 2, size unknown
- Serial number: local state only
- Purchase year: between 2017 and 2019
- Windows edition and build: unknown until preflight
- Display version: unknown until preflight

## Hardware

- CPU: Intel Core i7-8650U
- CPU generation: 8th
- RAM: 16 GB
- System drive free space:
- GPU:
- Battery count and health:

## Platform state

- Windows 10 ESU enrolled: unknown
- Windows 11 eligible: likely, pending TPM and Secure Boot check
- TPM 2.0:
- Secure Boot:
- Admin account available:

## Tooling

- winget:
- git:
- gh:
- op:
- pwsh:
- mise:
- codex:
- claude:

# Hardware: Surface Book 2

The purchase window (2017 to 2019) points at the Surface Book 2, released on
2017-11-16. Two sizes exist and they differ in the one fact that decides the
operating system: CPU generation.

## Variants

| Size | CPU | Generation | RAM | GPU |
| --- | --- | --- | --- | --- |
| 13.5 inch | Intel Core i5-7300U | 7th | 8 GB | Intel HD 620 |
| 13.5 inch | Intel Core i5-8350U | 8th | 8 or 16 GB | Intel UHD 620 |
| 13.5 inch | Intel Core i7-8650U | 8th | 8 or 16 GB | UHD 620 or GTX 1050 2 GB |
| 15 inch | Intel Core i7-8650U | 8th | 16 GB | GTX 1060 6 GB |

Storage options were 128 GB, 256 GB, 512 GB and 1 TB. All models shipped
with Windows 10 Pro, TPM 2.0 and Windows Hello.

The i5-8350U variant arrived in March 2019. A machine bought in 2017 or 2018
is most likely the i5-7300U or i7-8650U.

## What decides Windows 11

Windows 11 requires an 8th generation Intel CPU or newer, TPM 2.0, Secure
Boot and 4 GB of RAM. The Surface Book 2 has TPM 2.0 and Secure Boot, so the
CPU is the blocker.

- i5-7300U: below the CPU floor. Microsoft does not support Windows 11.
- i5-8350U and i7-8650U: meet the published CPU requirement.

Run this on the machine and record the answer:

```powershell
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors
Get-CimInstance Win32_PhysicalMemory | Select-Object Capacity, Speed
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size, HealthStatus
```

`steps/10-preflight.ps1` writes the same facts to
`%LOCALAPPDATA%\oli-windows\system-info.json`.

## Support status of the hardware

Microsoft ended firmware and driver updates for the Surface Book 2 on
2023-05-30. Windows may still install generic drivers, but Surface-specific
fixes are no longer published. Treat hardware quirks as permanent.

The 15 inch model can draw more power than its 95 W supply under sustained
CPU and GPU load, which drains the battery while plugged in. Do not use it
for long compute jobs on battery.

## Battery check

The preflight step writes an HTML battery report to
`%LOCALAPPDATA%\oli-windows\battery-report.html`. Open it and check design
capacity against full charge capacity. A 2017 battery that sat unused for
years may be swollen or deeply discharged. If the case is deformed, stop and
replace the battery before leaving the machine plugged in.

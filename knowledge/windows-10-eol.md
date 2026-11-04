# Windows 10 support status

Checked on 2026-11-05 against Microsoft's lifecycle and end-of-support pages.

## Dates

| Fact | Date |
| --- | --- |
| Windows 10 end of support | 2025-10-14 |
| Consumer ESU end | 2027-10-12 |
| Microsoft 365 apps security updates on Windows 10 end | 2028-10-10 |
| Surface Book 2 firmware and driver updates ended | 2023-05-30 |

Windows 10 22H2 was the final feature update. After 2025-10-14 there are no
security fixes, feature updates or technical support without ESU.

## Consumer ESU

Any personal Windows 10 22H2 device is eligible in most markets. Enrol from
Settings > Update & Security > Windows Update. The three enrolment routes
are:

- No extra cost when PC settings sync through a Microsoft account.
- 1,000 Microsoft Rewards points.
- A one-time USD 30 payment.

One licence covers up to 10 devices. ESU provides critical and important
security updates only. It does not provide feature updates or technical
support beyond activation help.

## What this means for the Surface Book

The machine must not browse the internet, read email or run agents while it
is an unpatched Windows 10 install. Enrol in ESU first, or install Windows 11
if the CPU allows it.

The bootstrap does not enrol in ESU. Enrolment needs a Microsoft account and
a human decision. The preflight step reports the build and the blockers, and
the runbook in `docs/new-machine-runbook.md` puts ESU before tooling.

## Windows 11 check

Use the Microsoft PC Health Check app:

<https://aka.ms/GetPCHealthCheckApp>

The detected facts in `system-info.json` are a guide, not a certification.
The i5-7300U model cannot upgrade officially. The 8th generation models can.

## Sources

- <https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro>
- <https://www.microsoft.com/en-us/windows/end-of-support>
- <https://en.wikipedia.org/wiki/Surface_Book_2>

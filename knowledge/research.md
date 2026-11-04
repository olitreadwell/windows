# Research notes

Checked 2026-11-05. Primary sources first, then vendor documentation.

## Windows 10 lifecycle

Microsoft Learn says Windows 10 reached end of support on 2025-10-14 and
22H2 was the final version:

<https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro>

The consumer end-of-support page says ESU continues through 2027-10-12 and
lists the three enrolment routes. It also says Microsoft 365 apps on Windows
10 keep security updates until 2028-10-10:

<https://www.microsoft.com/en-us/windows/end-of-support>

## Surface Book 2

Wikipedia lists both sizes, the CPU options, RAM, storage and GPU, and cites
Microsoft's 2023-05-30 end of firmware and driver updates:

<https://en.wikipedia.org/wiki/Surface_Book_2>

The i5-8350U variant was added in March 2019. The i5-7300U is 7th
generation, so it is outside the Windows 11 CPU floor. The i7-8650U and
i5-8350U are 8th generation.

## 1Password SSH agent on Windows

1Password developer documentation says the agent listens on the system-wide
pipe `\\.\pipe\openssh-ssh-agent` and that the Windows OpenSSH Authentication
Agent service must not hold it:

<https://developer.1password.com/docs/ssh/get-started/>

The ssh client config therefore uses:

```text
Host *
  IdentityAgent "//./pipe/openssh-ssh-agent"
```

## winget package IDs

Every ID in `config/packages.txt` was checked against the manifest tree in
`microsoft/winget-pkgs` on 2026-11-05. Re-check an ID before adding it,
because publishers rename packages.

## Open questions

1. Exact Surface Book 2 model and CPU. Resolve with preflight on the machine.
2. Whether the machine is eligible for Windows 11.
3. Whether native Codex on Windows needs WSL for the sandbox.
4. Whether `mise` can install every runtime in `config/mise.toml` on Windows.

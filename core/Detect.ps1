# Machine detection. Everything returns data; nothing here changes the system.
Set-StrictMode -Version 2.0

function Get-CpuGeneration {
    param([string]$Name)

    if ($Name -match 'Ultra') { return 15 }
    if ($Name -match 'i[3579]-(\d{4})') {
        $number = [int]$Matches[1]
        if ($number -ge 1000 -and $number -lt 2000) { return [int][math]::Floor($number / 100) }
        return [int][math]::Floor($number / 1000)
    }
    return 0
}

function Get-MachineInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS
    $video = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })

    $build = [int]$os.BuildNumber
    $displayVersion = ''
    try {
        $displayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).DisplayVersion
    }
    catch { Write-Verbose 'display version unavailable' }

    $systemDrive = $env:SystemDrive.TrimEnd(':')
    $freeGb = 0
    try {
        $freeGb = [math]::Round((Get-PSDrive -Name $systemDrive -ErrorAction Stop).Free / 1GB, 1)
    }
    catch { Write-Verbose 'system drive free space unavailable' }

    $ramGb = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    $tpmEnabled = $false
    try {
        $tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
        $tpmEnabled = [bool]($tpm -and $tpm.IsEnabled_InitialValue)
    }
    catch { Write-Verbose 'TPM query unavailable' }

    $secureBoot = $null
    try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { Write-Verbose 'Secure Boot query unavailable' }

    $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    $batteryPercent = $null
    if ($batteries.Count -gt 0 -and $batteries[0].PSObject.Properties['EstimatedChargeRemaining']) {
        $batteryPercent = $batteries[0].EstimatedChargeRemaining
    }
    $cpuGeneration = Get-CpuGeneration -Name $cpu.Name

    $blockers = @()
    if ($build -ge 22000) {
        $family = 'windows-11'
        $support = 'supported-build'
    }
    else {
        $family = 'windows-10'
        $support = 'out-of-support-build'
        if ($cpuGeneration -lt 1) { $blockers += 'CPU model not recognized; check the Microsoft supported CPU list' }
        elseif ($cpuGeneration -lt 8) { $blockers += "CPU generation $cpuGeneration (Windows 11 needs 8th gen or newer)" }
        if (-not $tpmEnabled) { $blockers += 'TPM 2.0 not detected or not enabled' }
        if ($secureBoot -ne $true) { $blockers += 'Secure Boot not confirmed' }
        if ($ramGb -lt 4) { $blockers += 'Less than 4 GB RAM' }
        if ($freeGb -lt 64) { $blockers += 'Less than 64 GB free on the system drive' }
    }

    return [ordered]@{
        ComputerName        = $env:COMPUTERNAME
        Manufacturer        = $computer.Manufacturer
        Model               = $computer.Model
        SerialNumber        = $bios.SerialNumber
        WindowsCaption      = $os.Caption
        WindowsVersion      = $os.Version
        DisplayVersion      = $displayVersion
        BuildNumber         = $build
        UpdateBuildRevision = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).UBR
        Architecture        = $os.OSArchitecture
        CpuName             = $cpu.Name
        CpuCores            = $cpu.NumberOfCores
        CpuLogical          = $cpu.NumberOfLogicalProcessors
        CpuGeneration       = $cpuGeneration
        RamGb               = $ramGb
        SystemDriveFreeGb   = $freeGb
        Gpu                 = $video -join '; '
        TpmEnabled          = $tpmEnabled
        SecureBoot          = $secureBoot
        BatteryCount        = $batteries.Count
        BatteryPercent      = $batteryPercent
        WindowsFamily       = $family
        WindowsSupport      = $support
        Windows11Blockers   = $blockers
        Windows11Likely     = ($blockers.Count -eq 0)
        Winget              = (Test-CommandExists 'winget')
        Git                 = (Test-CommandExists 'git')
        Gh                  = (Test-CommandExists 'gh')
        Op                  = (Test-CommandExists 'op')
        Pwsh                = (Test-CommandExists 'pwsh')
        Mise                = (Test-CommandExists 'mise')
        Codex               = (Test-CommandExists 'codex')
        Claude              = (Test-CommandExists 'claude')
        IsAdmin             = (Test-IsAdmin)
        DetectedAt          = (Get-Date).ToString('s')
    }
}

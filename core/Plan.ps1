# Ordered step list. Filename order is execution order.
Set-StrictMode -Version 2.0

function Get-StepPlan {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$From,
        [string]$Only
    )

    $stepsDir = Join-Path $RepoRoot 'steps'
    $steps = @(Get-ChildItem -Path $stepsDir -Filter '*.ps1' | Sort-Object { [int](($_.BaseName -split '-')[0]) } | ForEach-Object { $_.BaseName })

    if ($Only) {
        $wanted = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        return @($steps | Where-Object { $wanted -contains $_ })
    }

    if ($From) {
        $index = [Array]::IndexOf($steps, $From)
        if ($index -lt 0) { return @() }
        return @($steps[$index..($steps.Count - 1)])
    }

    return $steps
}

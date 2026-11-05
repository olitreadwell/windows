# Clone personal repos into ~/code. Manifest: repos.txt.
Set-StrictMode -Version 2.0

$manifest = Join-Path $global:OliRepoRoot 'repos.txt'
if (-not (Test-Path $manifest)) {
    Write-Log 'no repos.txt manifest; skipping'
    return
}

$freeGb = [math]::Round((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
if ($freeGb -lt 30) {
    Write-Warn ("only {0} GB free; skipping repo clones. Run this step later: .\bootstrap.ps1 -Only 65-repos" -f $freeGb)
    return
}

$codeDir = Join-Path $HOME 'code'
if (-not (Test-Path $codeDir)) { New-Item -ItemType Directory -Path $codeDir -Force | Out-Null }

$useGh = (Test-CommandExists 'gh')
if ($useGh) {
    & gh auth status 2>&1 | Out-Null
    $useGh = ($LASTEXITCODE -eq 0)
}

foreach ($raw in Get-Content -LiteralPath $manifest) {
    $repo = $raw.Trim()
    if ($repo -eq '' -or $repo.StartsWith('#')) { continue }

    $destination = Join-Path $codeDir $repo
    if (Test-Path (Join-Path $destination '.git')) {
        & git -C $destination pull --ff-only origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warn "pull failed: $repo" }
        continue
    }

    if (-not $useGh -and $global:OliAssumeYes) {
        Write-Warn ("needs gh auth; skipping clone: {0}" -f $repo)
        continue
    }

    $backup = $null
    if (Test-Path $destination) {
        $backup = "$destination.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Move-Item -LiteralPath $destination -Destination $backup
        Write-Warn "moved non-git directory aside: $destination -> $backup"
    }

    if ($useGh) { & gh repo clone ("olitreadwell/{0}" -f $repo) $destination }
    else { & git clone ("https://github.com/olitreadwell/{0}.git" -f $repo) $destination }

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "clone failed: $repo"
        if ($backup) {
            if (Test-Path $destination) { Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue }
            Move-Item -LiteralPath $backup -Destination $destination -ErrorAction SilentlyContinue
            Write-Warn "restored the original directory: $destination"
        }
    }
    else { Write-Ok "cloned: $repo" }
}

#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
    [string[]]$Only,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    @'
npm-gl-update - check for and update outdated global npm packages

Usage:
  npm-gl-update [options]

Options:
  -Check        Only report outdated packages, do not install
  -Force        Update packages even if already on the wanted/latest version
  -Only <name>  Only consider the given package(s); can be repeated or comma-separated
  -Help         Show this help

Notes:
  - When Node/npm is managed by nvm (NVM_HOME/NVM_SYMLINK set, or the global
    prefix equals the Node install dir), npm is bundled per Node version and is
    skipped. Use nvm to switch/install Node versions to update it.
  - Otherwise npm itself is updated last and via a separate install to avoid
    clobbering the running npm process.
  - Requires network access to the npm registry.
'@ | Write-Host
    exit 0
}

function Get-GlobalPackages {
    $json = npm ls -g --depth=0 --json 2>$null | Out-String
    if (-not $json.Trim()) { return @() }
    try { $data = $json | ConvertFrom-Json } catch { return @() }
    if (-not $data.dependencies) { return @() }
    $data.dependencies.PSObject.Properties | ForEach-Object {
        [pscustomobject]@{
            Name    = $_.Name
            Version = $_.Value.version
        }
    }
}

function Get-LatestVersion([string]$name) {
    try {
        $v = npm view $name version 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($v)) { return $null }
        return $v.Trim()
    } catch {
        return $null
    }
}

function ConvertTo-SortableVersion([string]$version) {
    # Strip semver build metadata and pre-release tag for a coarse numeric compare.
    $core = ($version -split '\+')[0]
    $core = ($core -split '-')[0]
    $parts = @($core -split '\.')
    while ($parts.Count -lt 3) { $parts += '0' }
    $nums = @()
    foreach ($p in $parts[0..2]) {
        $n = 0
        [void][int]::TryParse($p, [ref]$n)
        $nums += $n
    }
    return $nums
}

function Test-IsNewer([string]$latest, [string]$current) {
    $l = ConvertTo-SortableVersion $latest
    $c = ConvertTo-SortableVersion $current
    for ($i = 0; $i -lt 3; $i++) {
        if ($l[$i] -gt $c[$i]) { return $true }
        if ($l[$i] -lt $c[$i]) { return $false }
    }
    return $false
}

function Test-NvmManagedNpm {
    # npm ships bundled with each Node version when installed via nvm. Under
    # nvm-windows the global prefix is the Node install root itself (a symlink
    # such as nvm4w\nodejs -> nvm\vX), so it is managed by nvm (switch/install a
    # Node version) rather than by `npm install -g npm@latest`.
    if ($env:NVM_HOME -or $env:NVM_SYMLINK) { return $true }
    try {
        $prefix = (npm prefix -g 2>$null | Out-String).Trim().TrimEnd('\', '/')
        if (-not $prefix) { return $false }
        $nodeDir = (Split-Path -Parent (node -e "console.log(process.execPath)" 2>$null)).TrimEnd('\', '/')
        if (-not $nodeDir) { return $false }
        # Exact match only: npm bundled with Node shares the Node install root.
        return $prefix.Equals($nodeDir, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

Write-Host "Collecting global npm packages..." -ForegroundColor Cyan
$nvmManaged = Test-NvmManagedNpm
$packages = @(Get-GlobalPackages)
if ($packages.Count -eq 0) {
    Write-Host "No global packages found." -ForegroundColor Yellow
    exit 0
}

$filter = @()
foreach ($item in $Only) {
    $filter += ($item -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}
if ($filter.Count -gt 0) {
    $packages = @($packages | Where-Object { $filter -contains $_.Name })
    if ($packages.Count -eq 0) {
        Write-Host "None of the requested packages are installed globally." -ForegroundColor Yellow
        exit 0
    }
}

$outdated = @()
$checked = 0
foreach ($pkg in $packages) {
    $checked++
    Write-Progress -Activity "Checking for updates" -Status $pkg.Name -PercentComplete (($checked / $packages.Count) * 100)
    if ($nvmManaged -and $pkg.Name -eq 'npm') {
        Write-Host ("  - {0} {1} (managed by nvm, skipped)" -f $pkg.Name, $pkg.Version) -ForegroundColor DarkGray
        continue
    }
    $latest = Get-LatestVersion $pkg.Name
    if (-not $latest) {
        Write-Host ("  ? {0}: could not resolve latest version" -f $pkg.Name) -ForegroundColor DarkGray
        continue
    }
    if ((Test-IsNewer -latest $latest -current $pkg.Version) -or $Force) {
        $outdated += [pscustomobject]@{
            Name    = $pkg.Name
            Current = $pkg.Version
            Latest  = $latest
        }
    } else {
        Write-Host ("  = {0} {1} (up to date)" -f $pkg.Name, $pkg.Version) -ForegroundColor DarkGray
    }
}
Write-Progress -Activity "Checking for updates" -Completed

if ($outdated.Count -eq 0) {
    Write-Host "`nAll global packages are up to date." -ForegroundColor Green
    exit 0
}

Write-Host "`nOutdated global packages:" -ForegroundColor Yellow
$outdated | ForEach-Object {
    Write-Host ("  {0}: {1} -> {2}" -f $_.Name, $_.Current, $_.Latest) -ForegroundColor Yellow
}

if ($Check) {
    Write-Host "`n(-Check specified; nothing installed.)" -ForegroundColor Cyan
    exit 1
}

$failed = @()
foreach ($pkg in $outdated) {
    if ($nvmManaged -and $pkg.Name -eq 'npm') { continue }
    Write-Host ("`nUpdating {0} {1} -> {2} ..." -f $pkg.Name, $pkg.Current, $pkg.Latest) -ForegroundColor Cyan
    npm install -g "$($pkg.Name)@latest"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("  ! failed to update {0}" -f $pkg.Name) -ForegroundColor Red
        $failed += $pkg.Name
    } else {
        Write-Host ("  + {0} updated" -f $pkg.Name) -ForegroundColor Green
    }
}

$npmPkg = $outdated | Where-Object { $_.Name -eq 'npm' }
if ($npmPkg -and -not $nvmManaged) {
    Write-Host ("`nUpdating npm {0} -> {1} (self, last) ..." -f $npmPkg.Current, $npmPkg.Latest) -ForegroundColor Cyan
    npm install -g "npm@latest"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ! failed to update npm" -ForegroundColor Red
        $failed += 'npm'
    } else {
        Write-Host "  + npm updated" -ForegroundColor Green
    }
}

if ($failed.Count -gt 0) {
    Write-Host ("`nCompleted with failures: {0}" -f ($failed -join ', ')) -ForegroundColor Red
    exit 1
}

Write-Host "`nAll global packages updated." -ForegroundColor Green
exit 0

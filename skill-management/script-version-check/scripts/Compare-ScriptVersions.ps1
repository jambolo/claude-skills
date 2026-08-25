<#
.SYNOPSIS
Compares the versions recorded in a scripts repo's manifest.json
against the versions of the same bash scripts installed in the user's ~/bin.

.DESCRIPTION
Emits one row per manifest entry with the manifest version, the version
declared in the repo copy's `# version:` header, the version in the installed
copy's header, and a status:

  OK          local version equals the manifest version
  OUTDATED    local version is older than the manifest version
  AHEAD       local version is newer than the manifest version
  MISSING     nothing installed at the entry's install path
  UNVERSIONED installed file has no `# version:` header comment
  DIFFERENT   versions differ but are not comparable as System.Version

Every manifest entry declares `kind: script`; there is no default and no other
kind, and an entry with a missing or different kind is an error. The layout is:

  script  repo <path>  -> <InstallRoot>\<name>

A script's version is the first line matching `# version: <value>`
(case-insensitive `version`) within the first 15 lines of the file.

Also reports manifest drift (manifest version != repo header version). The
install root is not owned by the repo, so unlike Compare-SkillVersions.ps1
there is no "installed but not in manifest" section.

.PARAMETER RepoRoot
Root of the scripts repo (the folder holding manifest.json). Defaults
to the nearest ancestor of the current directory containing one.

.PARAMETER InstallRoot
Script install root. Defaults to $env:USERPROFILE\bin.

.PARAMETER Json
Emit a JSON report on stdout instead of formatted tables.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'bin'),
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Start)
    $dir = Get-Item -LiteralPath $Start
    while ($null -ne $dir) {
        if (Test-Path -LiteralPath (Join-Path $dir.FullName 'manifest.json')) { return $dir.FullName }
        $dir = $dir.Parent
    }
    return $null
}

function Get-HeaderVersion {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path -TotalCount 15)
    foreach ($line in $lines) {
        if ($line -match '^#\s*[Vv]ersion:\s*(.+?)\s*$') { return $matches[1] }
    }
    return $null
}

function Compare-Version {
    param([string]$Local, [string]$Manifest)
    if ($Local -eq $Manifest) { return 'OK' }
    try {
        if ([version]$Local -lt [version]$Manifest) { return 'OUTDATED' } else { return 'AHEAD' }
    } catch {
        return 'DIFFERENT'
    }
}

if (-not $RepoRoot) { $RepoRoot = Resolve-RepoRoot -Start (Get-Location).Path }
if (-not $RepoRoot) { throw 'manifest.json not found. Pass -RepoRoot <path to the scripts repo>.' }

$manifestPath = Join-Path $RepoRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Manifest not found: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$entries = @($manifest.entries)
if ($entries.Count -eq 0) { throw "No entries found in $manifestPath (manifestVersion 1 expects an 'entries' array)." }

$rows = foreach ($e in $entries) {
    $kind = if ($e.PSObject.Properties['kind']) { [string]$e.kind } else { '' }
    if ($kind -ne 'script') {
        throw "Manifest entry '$($e.name)' has kind '$kind'; every entry must declare kind as 'script'."
    }

    $repoFile  = Join-Path $RepoRoot $e.path
    $localFile = Join-Path $InstallRoot $e.name

    $repoVersion  = Get-HeaderVersion -Path $repoFile
    $localVersion = Get-HeaderVersion -Path $localFile

    $status =
        if (-not (Test-Path -LiteralPath $localFile)) { 'MISSING' }
        elseif (-not $localVersion) { 'UNVERSIONED' }
        else { Compare-Version -Local $localVersion -Manifest $e.version }

    [pscustomobject]@{
        Name       = $e.name
        Kind       = $kind
        Manifest   = $e.version
        Repo       = if ($repoVersion) { $repoVersion } else { '(none)' }
        Local      = if ($localVersion) { $localVersion } else { '(none)' }
        Status     = $status
        Drift      = ($repoVersion -ne $e.version)
        RepoPath   = $repoFile
        LocalPath  = $localFile
    }
}

if ($Json) {
    [pscustomobject]@{
        repoRoot    = $RepoRoot
        installRoot = $InstallRoot
        entries     = $rows
    } | ConvertTo-Json -Depth 5
    return
}

Write-Output "Repo:    $RepoRoot"
Write-Output "Scripts: $InstallRoot"
Write-Output ''
$rows | Format-Table Name, Kind, Manifest, Repo, Local, Status -AutoSize | Out-String -Width 200 | Write-Output

$drifted = @($rows | Where-Object { $_.Drift })
if ($drifted.Count -gt 0) {
    Write-Output 'Manifest drift (manifest version != repo header version):'
    $drifted | Format-Table Name, Kind, Manifest, Repo -AutoSize | Out-String -Width 200 | Write-Output
}

$counts = $rows | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("Summary: " + ($counts -join ' '))

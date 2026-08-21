<#
.SYNOPSIS
Compares the skill versions recorded in this repo's skills-manifest.json against
the versions of the same skills installed under the user's Claude skills root.

.DESCRIPTION
Emits one row per manifest entry with the manifest version, the version actually
declared in the repo's SKILL.md, the version installed locally, and a status:

  OK          local version equals the manifest version
  OUTDATED    local version is older than the manifest version
  AHEAD       local version is newer than the manifest version
  MISSING     no skill folder installed at <InstallRoot>\<name>
  UNVERSIONED installed SKILL.md has no version: field in its frontmatter
  DIFFERENT   versions differ but are not comparable as System.Version

Also reports manifest drift (manifest version != repo SKILL.md version) and
installed skills that the manifest does not know about.

.PARAMETER RepoRoot
Root of the claude-skills repo (the folder holding skills-manifest.json).
Defaults to the nearest ancestor of the current directory containing one.

.PARAMETER InstallRoot
Claude skills install root. Defaults to $env:USERPROFILE\.claude\skills.

.PARAMETER Json
Emit a JSON report on stdout instead of formatted tables.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$InstallRoot = (Join-Path $env:USERPROFILE '.claude\skills'),
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Start)
    $dir = Get-Item -LiteralPath $Start
    while ($null -ne $dir) {
        if (Test-Path -LiteralPath (Join-Path $dir.FullName 'skills-manifest.json')) { return $dir.FullName }
        $dir = $dir.Parent
    }
    return $null
}

function Get-FrontmatterField {
    param([string]$Path, [string]$Field)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match ('^{0}:\s*("?)([^"#]+)\1\s*$' -f [regex]::Escape($Field))) {
            return $matches[2].Trim()
        }
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
if (-not $RepoRoot) { throw 'skills-manifest.json not found. Pass -RepoRoot <path to claude-skills repo>.' }

$manifestPath = Join-Path $RepoRoot 'skills-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Manifest not found: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$rows = foreach ($s in $manifest.skills) {
    $repoMd  = Join-Path $RepoRoot (Join-Path $s.path 'SKILL.md')
    $localDir = Join-Path $InstallRoot $s.name
    $localMd = Join-Path $localDir 'SKILL.md'

    $repoVersion  = Get-FrontmatterField -Path $repoMd  -Field 'version'
    $localVersion = Get-FrontmatterField -Path $localMd -Field 'version'

    $status =
        if (-not (Test-Path -LiteralPath $localMd)) { 'MISSING' }
        elseif (-not $localVersion) { 'UNVERSIONED' }
        else { Compare-Version -Local $localVersion -Manifest $s.version }

    [pscustomobject]@{
        Skill      = $s.name
        Manifest   = $s.version
        Repo       = if ($repoVersion) { $repoVersion } else { '(none)' }
        Local      = if ($localVersion) { $localVersion } else { '(none)' }
        Status     = $status
        Drift      = ($repoVersion -ne $s.version)
        RepoPath   = (Split-Path -Parent $repoMd)
        LocalPath  = $localDir
    }
}

$known = $manifest.skills.name
$orphans = @()
if (Test-Path -LiteralPath $InstallRoot) {
    $orphans = @(Get-ChildItem -LiteralPath $InstallRoot -Directory |
        Where-Object { $known -notcontains $_.Name } |
        ForEach-Object {
            [pscustomobject]@{
                Skill   = $_.Name
                Local   = (Get-FrontmatterField -Path (Join-Path $_.FullName 'SKILL.md') -Field 'version')
                Path    = $_.FullName
            }
        })
}

if ($Json) {
    [pscustomobject]@{
        repoRoot    = $RepoRoot
        installRoot = $InstallRoot
        skills      = $rows
        orphans     = $orphans
    } | ConvertTo-Json -Depth 5
    return
}

Write-Output "Repo:    $RepoRoot"
Write-Output "Install: $InstallRoot"
Write-Output ''
$rows | Format-Table Skill, Manifest, Repo, Local, Status -AutoSize | Out-String -Width 200 | Write-Output

$drifted = @($rows | Where-Object { $_.Drift })
if ($drifted.Count -gt 0) {
    Write-Output 'Manifest drift (manifest version != repo SKILL.md version):'
    $drifted | Format-Table Skill, Manifest, Repo -AutoSize | Out-String -Width 200 | Write-Output
}

if ($orphans.Count -gt 0) {
    Write-Output 'Installed but not in manifest:'
    $orphans | Format-Table Skill, Local, Path -AutoSize | Out-String -Width 200 | Write-Output
}

$counts = $rows | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("Summary: " + ($counts -join ' '))

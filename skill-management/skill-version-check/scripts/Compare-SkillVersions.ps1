<#
.SYNOPSIS
Compares the versions recorded in this repo's skills-manifest.json against the
versions of the same skills and agents installed under the user's Claude config.

.DESCRIPTION
Emits one row per manifest entry with the manifest version, the version actually
declared in the repo's SKILL.md / AGENT.md, the version installed locally, and a
status:

  OK          local version equals the manifest version
  OUTDATED    local version is older than the manifest version
  AHEAD       local version is newer than the manifest version
  MISSING     nothing installed at the entry's install path
  UNVERSIONED installed file has no version: field in its frontmatter
  DIFFERENT   versions differ but are not comparable as System.Version

Every manifest entry declares a `kind`; there is no default, and an entry with a
missing or unrecognized kind is an error. The kind selects the layout:

  skill  repo <path>\SKILL.md   -> <SkillInstallRoot>\<name>\SKILL.md
  agent  repo <path>\AGENT.md   -> <AgentInstallRoot>\<name>.md

Also reports manifest drift (manifest version != repo frontmatter version) and
installed skills/agents that the manifest does not know about.

.PARAMETER RepoRoot
Root of the claude-skills repo (the folder holding skills-manifest.json).
Defaults to the nearest ancestor of the current directory containing one.

.PARAMETER SkillInstallRoot
Claude skills install root. Defaults to $env:USERPROFILE\.claude\skills.

.PARAMETER AgentInstallRoot
Claude agents install root. Defaults to $env:USERPROFILE\.claude\agents.

.PARAMETER Json
Emit a JSON report on stdout instead of formatted tables.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$SkillInstallRoot = (Join-Path $env:USERPROFILE '.claude\skills'),
    [string]$AgentInstallRoot = (Join-Path $env:USERPROFILE '.claude\agents'),
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

$entries = @($manifest.entries)
if ($entries.Count -eq 0) { throw "No entries found in $manifestPath (manifestVersion 2 expects an 'entries' array)." }

$rows = foreach ($e in $entries) {
    $kind = if ($e.PSObject.Properties['kind']) { [string]$e.kind } else { '' }
    switch ($kind) {
        'skill' {
            $repoMd    = Join-Path $RepoRoot (Join-Path $e.path 'SKILL.md')
            $localPath = Join-Path $SkillInstallRoot $e.name
            $localMd   = Join-Path $localPath 'SKILL.md'
        }
        'agent' {
            $repoMd    = Join-Path $RepoRoot (Join-Path $e.path 'AGENT.md')
            $localMd   = Join-Path $AgentInstallRoot "$($e.name).md"
            $localPath = $localMd
        }
        default {
            throw "Manifest entry '$($e.name)' has kind '$kind'; every entry must declare kind as 'skill' or 'agent'."
        }
    }

    $repoVersion  = Get-FrontmatterField -Path $repoMd  -Field 'version'
    $localVersion = Get-FrontmatterField -Path $localMd -Field 'version'

    $status =
        if (-not (Test-Path -LiteralPath $localMd)) { 'MISSING' }
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
        RepoPath   = (Split-Path -Parent $repoMd)
        LocalPath  = $localPath
    }
}

$knownSkills = @($rows | Where-Object { $_.Kind -eq 'skill' } | ForEach-Object { $_.Name })
$knownAgents = @($rows | Where-Object { $_.Kind -eq 'agent' } | ForEach-Object { $_.Name })
$orphans = @()
if (Test-Path -LiteralPath $SkillInstallRoot) {
    $orphans += @(Get-ChildItem -LiteralPath $SkillInstallRoot -Directory |
        Where-Object { $knownSkills -notcontains $_.Name } |
        ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Name
                Kind    = if ($knownAgents -contains $_.Name) { 'skill (superseded by agent)' } else { 'skill' }
                Local   = (Get-FrontmatterField -Path (Join-Path $_.FullName 'SKILL.md') -Field 'version')
                Path    = $_.FullName
            }
        })
}
if (Test-Path -LiteralPath $AgentInstallRoot) {
    $orphans += @(Get-ChildItem -LiteralPath $AgentInstallRoot -File -Filter '*.md' |
        Where-Object { $knownAgents -notcontains $_.BaseName } |
        ForEach-Object {
            [pscustomobject]@{
                Name    = $_.BaseName
                Kind    = if ($knownSkills -contains $_.BaseName) { 'agent (superseded by skill)' } else { 'agent' }
                Local   = (Get-FrontmatterField -Path $_.FullName -Field 'version')
                Path    = $_.FullName
            }
        })
}

if ($Json) {
    [pscustomobject]@{
        repoRoot         = $RepoRoot
        skillInstallRoot = $SkillInstallRoot
        agentInstallRoot = $AgentInstallRoot
        entries          = $rows
        orphans          = $orphans
    } | ConvertTo-Json -Depth 5
    return
}

Write-Output "Repo:    $RepoRoot"
Write-Output "Skills:  $SkillInstallRoot"
Write-Output "Agents:  $AgentInstallRoot"
Write-Output ''
$rows | Format-Table Name, Kind, Manifest, Repo, Local, Status -AutoSize | Out-String -Width 200 | Write-Output

$drifted = @($rows | Where-Object { $_.Drift })
if ($drifted.Count -gt 0) {
    Write-Output 'Manifest drift (manifest version != repo SKILL.md/AGENT.md version):'
    $drifted | Format-Table Name, Kind, Manifest, Repo -AutoSize | Out-String -Width 200 | Write-Output
}

if ($orphans.Count -gt 0) {
    Write-Output 'Installed but not in manifest:'
    $orphans | Format-Table Name, Kind, Local, Path -AutoSize | Out-String -Width 200 | Write-Output
}

$counts = $rows | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("Summary: " + ($counts -join ' '))

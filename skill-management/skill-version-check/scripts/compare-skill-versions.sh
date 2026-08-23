#!/usr/bin/env bash
# Compares the versions recorded in this repo's skills-manifest.json against
# the versions of the same skills and agents installed under the user's Claude
# config. POSIX/Linux counterpart of Compare-SkillVersions.ps1.
#
# Emits one row per manifest entry with the manifest version, the version
# declared in the repo's SKILL.md / AGENT.md, the version installed locally,
# and a status:
#
#   OK          local version equals the manifest version
#   OUTDATED    local version is older than the manifest version
#   AHEAD       local version is newer than the manifest version
#   MISSING     nothing installed at the entry's install path
#   UNVERSIONED installed file has no version: field in its frontmatter
#   DIFFERENT   versions differ but are not comparable as Major.Minor[.Build[.Revision]]
#
# Every manifest entry declares a `kind`; there is no default, and an entry
# with a missing or unrecognized kind is an error. The kind selects the layout:
#
#   skill  repo <path>/SKILL.md  -> <skill-install-root>/<name>/SKILL.md
#   agent  repo <path>/AGENT.md  -> <agent-install-root>/<name>.md
#
# Also reports manifest drift (manifest version != repo frontmatter version)
# and installed skills/agents the manifest does not know about.
#
# Usage:
#   compare-skill-versions.sh [--repo-root <path>] [--skill-install-root <path>]
#                             [--agent-install-root <path>] [--json]
#
#   --repo-root           Root of the claude-skills repo (the folder holding
#                         skills-manifest.json). Defaults to the nearest
#                         ancestor of the current directory containing one.
#   --skill-install-root  Claude skills install root. Defaults to
#                         $HOME/.claude/skills.
#   --agent-install-root  Claude agents install root. Defaults to
#                         $HOME/.claude/agents.
#   --json                Emit a JSON report on stdout instead of formatted tables.

set -euo pipefail

repo_root=""
skill_install_root="${HOME}/.claude/skills"
agent_install_root="${HOME}/.claude/agents"
json=0

die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo-root)          [ $# -ge 2 ] || die "--repo-root needs a value"; repo_root="$2"; shift 2 ;;
        --skill-install-root) [ $# -ge 2 ] || die "--skill-install-root needs a value"; skill_install_root="$2"; shift 2 ;;
        --agent-install-root) [ $# -ge 2 ] || die "--agent-install-root needs a value"; agent_install_root="$2"; shift 2 ;;
        --json)               json=1; shift ;;
        -h|--help)            usage; exit 0 ;;
        *)                    die "Unknown argument: $1" ;;
    esac
done

resolve_repo_root() {
    local dir
    dir="$(pwd -P)"
    while :; do
        if [ -f "$dir/skills-manifest.json" ]; then printf '%s\n' "$dir"; return 0; fi
        [ "$dir" = "/" ] && return 1
        dir="$(dirname "$dir")"
    done
}

# Reads a scalar frontmatter field from a SKILL.md / AGENT.md. Prints nothing
# when the file is absent, has no leading `---` fence, or lacks the field.
frontmatter_field() {
    local path="$1" field="$2"
    [ -f "$path" ] || return 0
    awk -v field="$field" '
        NR == 1 { if ($0 !~ /^[[:space:]]*---[[:space:]]*\r?$/) exit; next }
        /^[[:space:]]*---[[:space:]]*\r?$/ { exit }
        {
            line = $0
            sub(/\r$/, "", line)
            if (index(line, field ":") != 1) next
            value = substr(line, length(field) + 2)
            sub(/^[[:space:]]+/, "", value)
            sub(/#.*$/, "", value)
            sub(/[[:space:]]+$/, "", value)
            if (value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
            if (value == "") next
            print value
            exit
        }
    ' "$path"
}

# PowerShell [version] accepts 2-4 numeric components; anything else is DIFFERENT.
is_comparable_version() {
    printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+){1,3}$'
}

version_compare() {
    local local_v="$1" manifest_v="$2"
    if [ "$local_v" = "$manifest_v" ]; then printf 'OK\n'; return; fi
    if ! is_comparable_version "$local_v" || ! is_comparable_version "$manifest_v"; then
        printf 'DIFFERENT\n'; return
    fi
    local i a b
    local -a la mb
    IFS='.' read -r -a la <<< "$local_v"
    IFS='.' read -r -a mb <<< "$manifest_v"
    for i in 0 1 2 3; do
        a="${la[i]:-0}"; b="${mb[i]:-0}"
        if [ "$((10#$a))" -lt "$((10#$b))" ]; then printf 'OUTDATED\n'; return; fi
        if [ "$((10#$a))" -gt "$((10#$b))" ]; then printf 'AHEAD\n'; return; fi
    done
    printf 'OK\n'
}

json_escape() {
    printf '%s' "$1" | awk '
        BEGIN { RS = "\a" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "\\r")
            gsub(/\n/, "\\n")
            printf "%s", $0
        }'
}

[ -n "$repo_root" ] || repo_root="$(resolve_repo_root || true)"
[ -n "$repo_root" ] || die 'skills-manifest.json not found. Pass --repo-root <path to claude-skills repo>.'
repo_root="${repo_root%/}"
skill_install_root="${skill_install_root%/}"
agent_install_root="${agent_install_root%/}"

manifest_path="$repo_root/skills-manifest.json"
[ -f "$manifest_path" ] || die "Manifest not found: $manifest_path"

# Emits one TAB-separated `name<TAB>version<TAB>path<TAB>kind` line per manifest
# entry. `kind` is mandatory; an entry without one comes through empty and is
# rejected by the caller.
read_manifest() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.entries[] | [.name, .version, .path, (.kind // "")] | @tsv' "$manifest_path"
    else
        # Minimal scanner for the manifest shape: slurps the file, isolates the
        # "entries" array, and pulls name/version/path/kind out of each flat
        # object. Layout-independent (one object per line or per file), but it
        # assumes entry objects contain no nested objects or arrays, which the
        # manifest schema guarantees.
        awk '
            function field(obj, key,   re, s) {
                re = "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"[^\"]*\""
                if (!match(obj, re)) return ""
                s = substr(obj, RSTART, RLENGTH)
                sub(/^[^:]*:[ \t\r\n]*"/, "", s)
                sub(/"$/, "", s)
                return s
            }
            { data = data $0 "\n" }
            END {
                i = index(data, "\"entries\"")
                if (i == 0) exit 1
                rest = substr(data, i)
                j = index(rest, "[")
                if (j == 0) exit 1
                rest = substr(rest, j)
                k = index(rest, "]")
                if (k > 0) rest = substr(rest, 1, k)
                while (match(rest, /\{[^{}]*\}/)) {
                    obj = substr(rest, RSTART, RLENGTH)
                    rest = substr(rest, RSTART + RLENGTH)
                    name = field(obj, "name")
                    if (name != "") printf "%s\t%s\t%s\t%s\n", name, field(obj, "version"), field(obj, "path"), field(obj, "kind")
                }
            }
        ' "$manifest_path"
    fi
}

entries_tsv="$(read_manifest)"
[ -n "$entries_tsv" ] || die "No entries found in $manifest_path (manifestVersion 2 expects an 'entries' array)."

# Rows, TAB-separated: name, kind, manifest, repo, local, status, drift, repoPath, localPath
rows=""
known_skills=""
known_agents=""
while IFS=$'\t' read -r name manifest_version rel_path kind; do
    [ -n "$name" ] || continue
    case "$kind" in
        skill)
            repo_md="$repo_root/$rel_path/SKILL.md"
            local_path="$skill_install_root/$name"
            local_md="$local_path/SKILL.md"
            known_skills="${known_skills}${name}"$'\n'
            ;;
        agent)
            repo_md="$repo_root/$rel_path/AGENT.md"
            local_md="$agent_install_root/$name.md"
            local_path="$local_md"
            known_agents="${known_agents}${name}"$'\n'
            ;;
        *)
            die "Manifest entry '$name' has kind '$kind'; every entry must declare kind as 'skill' or 'agent'."
            ;;
    esac

    repo_version="$(frontmatter_field "$repo_md" version)"
    local_version="$(frontmatter_field "$local_md" version)"

    if [ ! -f "$local_md" ]; then
        status="MISSING"
    elif [ -z "$local_version" ]; then
        status="UNVERSIONED"
    else
        status="$(version_compare "$local_version" "$manifest_version")"
    fi

    drift="false"
    [ "$repo_version" = "$manifest_version" ] || drift="true"

    rows="${rows}${name}"$'\t'"${kind}"$'\t'"${manifest_version}"$'\t'"${repo_version:-(none)}"$'\t'"${local_version:-(none)}"$'\t'"${status}"$'\t'"${drift}"$'\t'"${repo_root}/${rel_path}"$'\t'"${local_path}"$'\n'
done <<< "$entries_tsv"

# Orphans, TAB-separated: name, kind, local version, path
orphans=""
if [ -d "$skill_install_root" ]; then
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        base="$(basename "$dir")"
        if printf '%s' "$known_skills" | grep -Fxq "$base"; then continue; fi
        okind="skill"
        if printf '%s' "$known_agents" | grep -Fxq "$base"; then okind="skill (superseded by agent)"; fi
        orphans="${orphans}${base}"$'\t'"${okind}"$'\t'"$(frontmatter_field "$dir/SKILL.md" version)"$'\t'"${dir}"$'\n'
    done <<< "$(find "$skill_install_root" -mindepth 1 -maxdepth 1 -type d | sort)"
fi
if [ -d "$agent_install_root" ]; then
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        base="$(basename "$file" .md)"
        if printf '%s' "$known_agents" | grep -Fxq "$base"; then continue; fi
        okind="agent"
        if printf '%s' "$known_skills" | grep -Fxq "$base"; then okind="agent (superseded by skill)"; fi
        orphans="${orphans}${base}"$'\t'"${okind}"$'\t'"$(frontmatter_field "$file" version)"$'\t'"${file}"$'\n'
    done <<< "$(find "$agent_install_root" -mindepth 1 -maxdepth 1 -type f -name '*.md' | sort)"
fi

if [ "$json" -eq 1 ]; then
    printf '{\n'
    printf '  "repoRoot": "%s",\n' "$(json_escape "$repo_root")"
    printf '  "skillInstallRoot": "%s",\n' "$(json_escape "$skill_install_root")"
    printf '  "agentInstallRoot": "%s",\n' "$(json_escape "$agent_install_root")"
    printf '  "entries": [\n'
    first=1
    while IFS=$'\t' read -r name kind mver rver lver status drift repo_path local_path; do
        [ -n "$name" ] || continue
        [ "$first" -eq 1 ] || printf ',\n'
        first=0
        printf '    { "Name": "%s", "Kind": "%s", "Manifest": "%s", "Repo": "%s", "Local": "%s", "Status": "%s", "Drift": %s, "RepoPath": "%s", "LocalPath": "%s" }' \
            "$(json_escape "$name")" "$(json_escape "$kind")" "$(json_escape "$mver")" "$(json_escape "$rver")" \
            "$(json_escape "$lver")" "$(json_escape "$status")" "$drift" \
            "$(json_escape "$repo_path")" "$(json_escape "$local_path")"
    done <<< "$rows"
    [ "$first" -eq 1 ] || printf '\n'
    printf '  ],\n'
    printf '  "orphans": [\n'
    first=1
    if [ -n "$orphans" ]; then
        while IFS=$'\t' read -r name kind lver opath; do
            [ -n "$name" ] || continue
            [ "$first" -eq 1 ] || printf ',\n'
            first=0
            if [ -n "$lver" ]; then ljson="\"$(json_escape "$lver")\""; else ljson='null'; fi
            printf '    { "Name": "%s", "Kind": "%s", "Local": %s, "Path": "%s" }' \
                "$(json_escape "$name")" "$(json_escape "$kind")" "$ljson" "$(json_escape "$opath")"
        done <<< "$orphans"
    fi
    [ "$first" -eq 1 ] || printf '\n'
    printf '  ]\n'
    printf '}\n'
    exit 0
fi

# Renders TAB-separated stdin as an aligned table under the given headers.
print_table() {
    awk -F '\t' -v headers="$1" '
        function pad(s, width) { return sprintf("%-" width "s", s) }
        BEGIN { n = split(headers, h, ","); for (i = 1; i <= n; i++) w[i] = length(h[i]) }
        $0 == "" { next }
        { rows[++r] = $0
          for (i = 1; i <= n; i++) if (length($i) > w[i]) w[i] = length($i) }
        END {
            for (i = 1; i <= n; i++) printf "%s%s", (i < n ? pad(h[i], w[i]) : h[i]), (i < n ? " " : "\n")
            for (i = 1; i <= n; i++) {
                bar = ""
                for (j = 0; j < w[i]; j++) bar = bar "-"
                printf "%s%s", bar, (i < n ? " " : "\n")
            }
            for (k = 1; k <= r; k++) {
                split(rows[k], f, "\t")
                for (i = 1; i <= n; i++) printf "%s%s", (i < n ? pad(f[i], w[i]) : f[i]), (i < n ? " " : "\n")
            }
        }'
}

printf 'Repo:    %s\n' "$repo_root"
printf 'Skills:  %s\n' "$skill_install_root"
printf 'Agents:  %s\n' "$agent_install_root"
printf '\n'
printf '%s' "$rows" | cut -f1-6 | print_table 'Name,Kind,Manifest,Repo,Local,Status'
printf '\n'

drifted="$(printf '%s' "$rows" | awk -F '\t' '$7 == "true" { print $1 "\t" $2 "\t" $3 "\t" $4 }')"
if [ -n "$drifted" ]; then
    printf 'Manifest drift (manifest version != repo SKILL.md/AGENT.md version):\n'
    printf '%s\n' "$drifted" | print_table 'Name,Kind,Manifest,Repo'
    printf '\n'
fi

if [ -n "$orphans" ]; then
    printf 'Installed but not in manifest:\n'
    printf '%s' "$orphans" | awk -F '\t' '{ print $1 "\t" $2 "\t" ($3 == "" ? "(none)" : $3) "\t" $4 }' | print_table 'Name,Kind,Local,Path'
    printf '\n'
fi

summary="$(printf '%s' "$rows" | awk -F '\t' '
    $0 == "" { next }
    { c[$6]++; if (!($6 in seen)) { seen[$6] = 1; order[++n] = $6 } }
    END {
        out = ""
        for (i = 1; i <= n; i++) out = out (i > 1 ? " " : "") order[i] "=" c[order[i]]
        print out
    }')"
printf 'Summary: %s\n' "$summary"

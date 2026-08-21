#!/usr/bin/env bash
# Compares the skill versions recorded in this repo's skills-manifest.json
# against the versions of the same skills installed under the user's Claude
# skills root. POSIX/Linux counterpart of Compare-SkillVersions.ps1.
#
# Emits one row per manifest entry with the manifest version, the version
# declared in the repo's SKILL.md, the version installed locally, and a status:
#
#   OK          local version equals the manifest version
#   OUTDATED    local version is older than the manifest version
#   AHEAD       local version is newer than the manifest version
#   MISSING     no skill folder installed at <install-root>/<name>
#   UNVERSIONED installed SKILL.md has no version: field in its frontmatter
#   DIFFERENT   versions differ but are not comparable as Major.Minor[.Build[.Revision]]
#
# Also reports manifest drift (manifest version != repo SKILL.md version) and
# installed skills the manifest does not know about.
#
# Usage:
#   compare-skill-versions.sh [--repo-root <path>] [--install-root <path>] [--json]
#
#   --repo-root     Root of the claude-skills repo (the folder holding
#                   skills-manifest.json). Defaults to the nearest ancestor of
#                   the current directory containing one.
#   --install-root  Claude skills install root. Defaults to $HOME/.claude/skills.
#   --json          Emit a JSON report on stdout instead of formatted tables.

set -euo pipefail

repo_root=""
install_root="${HOME}/.claude/skills"
json=0

die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo-root)    [ $# -ge 2 ] || die "--repo-root needs a value"; repo_root="$2"; shift 2 ;;
        --install-root) [ $# -ge 2 ] || die "--install-root needs a value"; install_root="$2"; shift 2 ;;
        --json)         json=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "Unknown argument: $1" ;;
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

# Reads a scalar frontmatter field from a SKILL.md. Prints nothing when the file
# is absent, has no leading `---` fence, or lacks the field.
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
install_root="${install_root%/}"

manifest_path="$repo_root/skills-manifest.json"
[ -f "$manifest_path" ] || die "Manifest not found: $manifest_path"

# Emits one TAB-separated `name<TAB>version<TAB>path` line per manifest skill.
read_manifest() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.skills[] | [.name, .version, .path] | @tsv' "$manifest_path"
    else
        # Minimal scanner for the manifest shape: slurps the file, isolates the
        # "skills" array, and pulls name/version/path out of each flat object.
        # Layout-independent (one object per line or per file), but it assumes
        # skill objects contain no nested objects or arrays, which the
        # manifestVersion 1 schema guarantees.
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
                i = index(data, "\"skills\"")
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
                    if (name != "") printf "%s\t%s\t%s\n", name, field(obj, "version"), field(obj, "path")
                }
            }
        ' "$manifest_path"
    fi
}

skills_tsv="$(read_manifest)"
[ -n "$skills_tsv" ] || die "No skills found in $manifest_path"

# Rows, TAB-separated: skill, manifest, repo, local, status, drift, repoPath, localPath
rows=""
known=""
while IFS=$'\t' read -r name manifest_version rel_path; do
    [ -n "$name" ] || continue
    repo_md="$repo_root/$rel_path/SKILL.md"
    local_dir="$install_root/$name"
    local_md="$local_dir/SKILL.md"

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

    rows="${rows}${name}"$'\t'"${manifest_version}"$'\t'"${repo_version:-(none)}"$'\t'"${local_version:-(none)}"$'\t'"${status}"$'\t'"${drift}"$'\t'"${repo_root}/${rel_path}"$'\t'"${local_dir}"$'\n'
    known="${known}${name}"$'\n'
done <<< "$skills_tsv"

# Orphans, TAB-separated: skill, local version, path
orphans=""
if [ -d "$install_root" ]; then
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        base="$(basename "$dir")"
        if printf '%s' "$known" | grep -Fxq "$base"; then continue; fi
        orphans="${orphans}${base}"$'\t'"$(frontmatter_field "$dir/SKILL.md" version)"$'\t'"${dir}"$'\n'
    done <<< "$(find "$install_root" -mindepth 1 -maxdepth 1 -type d | sort)"
fi

if [ "$json" -eq 1 ]; then
    printf '{\n'
    printf '  "repoRoot": "%s",\n' "$(json_escape "$repo_root")"
    printf '  "installRoot": "%s",\n' "$(json_escape "$install_root")"
    printf '  "skills": [\n'
    first=1
    while IFS=$'\t' read -r skill mver rver lver status drift repo_path local_path; do
        [ -n "$skill" ] || continue
        [ "$first" -eq 1 ] || printf ',\n'
        first=0
        printf '    { "Skill": "%s", "Manifest": "%s", "Repo": "%s", "Local": "%s", "Status": "%s", "Drift": %s, "RepoPath": "%s", "LocalPath": "%s" }' \
            "$(json_escape "$skill")" "$(json_escape "$mver")" "$(json_escape "$rver")" \
            "$(json_escape "$lver")" "$(json_escape "$status")" "$drift" \
            "$(json_escape "$repo_path")" "$(json_escape "$local_path")"
    done <<< "$rows"
    [ "$first" -eq 1 ] || printf '\n'
    printf '  ],\n'
    printf '  "orphans": [\n'
    first=1
    if [ -n "$orphans" ]; then
        while IFS=$'\t' read -r skill lver opath; do
            [ -n "$skill" ] || continue
            [ "$first" -eq 1 ] || printf ',\n'
            first=0
            if [ -n "$lver" ]; then ljson="\"$(json_escape "$lver")\""; else ljson='null'; fi
            printf '    { "Skill": "%s", "Local": %s, "Path": "%s" }' \
                "$(json_escape "$skill")" "$ljson" "$(json_escape "$opath")"
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
printf 'Install: %s\n' "$install_root"
printf '\n'
printf '%s' "$rows" | cut -f1-5 | print_table 'Skill,Manifest,Repo,Local,Status'
printf '\n'

drifted="$(printf '%s' "$rows" | awk -F '\t' '$6 == "true" { print $1 "\t" $2 "\t" $3 }')"
if [ -n "$drifted" ]; then
    printf 'Manifest drift (manifest version != repo SKILL.md version):\n'
    printf '%s\n' "$drifted" | print_table 'Skill,Manifest,Repo'
    printf '\n'
fi

if [ -n "$orphans" ]; then
    printf 'Installed but not in manifest:\n'
    printf '%s' "$orphans" | awk -F '\t' '{ print $1 "\t" ($2 == "" ? "(none)" : $2) "\t" $3 }' | print_table 'Skill,Local,Path'
    printf '\n'
fi

summary="$(printf '%s' "$rows" | awk -F '\t' '
    $0 == "" { next }
    { c[$5]++; if (!($5 in seen)) { seen[$5] = 1; order[++n] = $5 } }
    END {
        out = ""
        for (i = 1; i <= n; i++) out = out (i > 1 ? " " : "") order[i] "=" c[order[i]]
        print out
    }')"
printf 'Summary: %s\n' "$summary"

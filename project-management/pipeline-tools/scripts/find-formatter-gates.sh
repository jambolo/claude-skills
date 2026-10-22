#!/usr/bin/env bash
# Finds the repository tools that format, lint, or format-check Markdown, and for each
# prints whether its ignore mechanism already covers the pipeline artifacts and the exact
# entry to add when it does not. Reads only; never edits.
#
# Usage:
#   find-formatter-gates.sh --repo <path> --artifacts-dir <dir|.> --pattern <glob>
#     <glob> is the artifact file pattern, e.g. "my-plan-*.md" or "my-project-*.md".
#
# Prints one line per detected tool:
#   GATE <tool> config=<file> ignore=<file> covered=<yes|no> entry=<text to add>
# and "NONE" when no tool is detected. Exit 0 always (2 on usage).
#
# Tools: prettier, markdownlint-cli2, markdownlint-cli (legacy), dprint, pre-commit.
# pre-commit's exclude is a Python regex, not a glob; markdownlint-cli2 never reads
# .markdownlintignore.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="" adir="" pattern=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --artifacts-dir) adir="$2"; shift 2 ;;
        --pattern) pattern="$2"; shift 2 ;;
        *) usage_error "find-formatter-gates.sh --repo <path> --artifacts-dir <dir|.> --pattern <glob>" ;;
    esac
done
[[ -n "$repo" && -n "$adir" && -n "$pattern" ]] ||
    usage_error "find-formatter-gates.sh --repo <path> --artifacts-dir <dir|.> --pattern <glob>"
repo="$(cd "$repo" && pwd)"

adir="${adir%/}"
if [[ "$adir" == "." || -z "$adir" ]]; then
    glob="$pattern"
    regex_dir=""
else
    glob="$adir/$pattern"
    regex_dir="$adir/"
fi
# Python regex for pre-commit: the glob's "*" becomes ".*", "." is escaped.
regex="^${regex_dir}$(printf '%s' "$pattern" | sed -e 's/\./\\./g' -e 's/\*/.*/g')\$"

found=0

has_pkg_dep() {
    [[ -f "$repo/package.json" ]] && grep -qE "\"$1\"[[:space:]]*:" "$repo/package.json"
}

covered_line() {
    # covered_line <file> <needle>: does <file> contain a line equal to <needle> or a
    # directory-wide entry for the artifacts dir?
    local f="$1" needle="$2"
    [[ -f "$f" ]] || return 1
    grep -qxF -- "$needle" "$f" && return 0
    if [[ -n "$regex_dir" ]]; then
        grep -qxF -- "$regex_dir" "$f" && return 0
        grep -qxF -- "${regex_dir}**" "$f" && return 0
        grep -qxF -- "${regex_dir%/}" "$f" && return 0
    fi
    return 1
}

# Prettier
pconf=""
for f in .prettierrc .prettierrc.json .prettierrc.yaml .prettierrc.yml .prettierrc.toml .prettierrc.js .prettierrc.cjs .prettierrc.mjs prettier.config.js prettier.config.cjs prettier.config.mjs; do
    [[ -f "$repo/$f" ]] && { pconf="$f"; break; }
done
if [[ -z "$pconf" ]] && has_pkg_dep prettier; then pconf="package.json"; fi
if [[ -n "$pconf" ]]; then
    found=1
    if covered_line "$repo/.prettierignore" "$glob"; then c=yes; else c=no; fi
    echo "GATE prettier config=$pconf ignore=.prettierignore covered=$c entry=$glob"
fi

# markdownlint-cli2
mconf=""
for f in .markdownlint-cli2.jsonc .markdownlint-cli2.yaml .markdownlint-cli2.yml .markdownlint-cli2.cjs .markdownlint-cli2.mjs; do
    [[ -f "$repo/$f" ]] && { mconf="$f"; break; }
done
if [[ -z "$mconf" ]]; then
    if has_pkg_dep markdownlint-cli2 || { [[ -f "$repo/.pre-commit-config.yaml" ]] && grep -q "markdownlint-cli2" "$repo/.pre-commit-config.yaml"; } ||
       { [[ -d "$repo/.github/workflows" ]] && grep -rqs "markdownlint-cli2" "$repo/.github/workflows"; }; then
        mconf="(none: create .markdownlint-cli2.jsonc)"
    fi
fi
if [[ -n "$mconf" ]]; then
    found=1
    c=no
    if [[ -f "$repo/$mconf" ]] && grep -qF -- "\"$glob\"" "$repo/$mconf"; then c=yes; fi
    if [[ -f "$repo/$mconf" ]] && grep -qF -- "- $glob" "$repo/$mconf"; then c=yes; fi
    echo "GATE markdownlint-cli2 config=$mconf ignore=ignores-in-config covered=$c entry=$glob (add to the \"ignores\" array)"
fi

# markdownlint-cli (legacy): config without a cli2 config, or the package dependency.
lconf=""
if [[ -z "$mconf" ]]; then
    for f in .markdownlintrc .markdownlint.json .markdownlint.jsonc .markdownlint.yaml .markdownlint.yml; do
        [[ -f "$repo/$f" ]] && { lconf="$f"; break; }
    done
    if [[ -z "$lconf" ]] && has_pkg_dep markdownlint-cli; then lconf="package.json"; fi
fi
if [[ -n "$lconf" ]]; then
    found=1
    if covered_line "$repo/.markdownlintignore" "$glob"; then c=yes; else c=no; fi
    echo "GATE markdownlint-cli config=$lconf ignore=.markdownlintignore covered=$c entry=$glob"
fi

# dprint
dconf=""
for f in dprint.json .dprint.json dprint.jsonc .dprint.jsonc; do
    [[ -f "$repo/$f" ]] && { dconf="$f"; break; }
done
if [[ -n "$dconf" ]]; then
    found=1
    if grep -qF -- "\"$glob\"" "$repo/$dconf"; then c=yes; else c=no; fi
    echo "GATE dprint config=$dconf ignore=excludes-in-config covered=$c entry=$glob (add to \"excludes\")"
fi

# pre-commit with a Markdown-touching hook
if [[ -f "$repo/.pre-commit-config.yaml" ]] && grep -qiE "prettier|markdownlint|mdformat|dprint" "$repo/.pre-commit-config.yaml"; then
    found=1
    if grep -qF -- "$regex" "$repo/.pre-commit-config.yaml"; then c=yes; else c=no; fi
    echo "GATE pre-commit config=.pre-commit-config.yaml ignore=top-level-exclude covered=$c entry=$regex (Python regex; join an existing pattern with \\|)"
fi

[[ $found -eq 0 ]] && echo "NONE"
exit 0

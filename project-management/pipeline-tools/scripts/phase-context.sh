#!/usr/bin/env bash
# Prints the slice of a roadmap one phase's decomposition needs: everything above the
# first phase heading (title and strategy), then the "## Phase <N>" section up to the
# next level-2 heading. The other phases' sections are not printed.
#
# Usage: phase-context.sh --roadmap <markdown> --phase <N>
#
# Prints (stdout):
#   ROADMAP <path> phase <N> of <count>
#   <the preamble and the phase section, verbatim, CRs stripped>
# Exits 2 when the file is missing or has no "## Phase <N>" heading.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

roadmap="" phase=""
usage="phase-context.sh --roadmap <markdown> --phase <N>"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --roadmap) roadmap="$2"; shift 2 ;;
        --phase) phase="$2"; shift 2 ;;
        *) usage_error "$usage" ;;
    esac
done
[[ -n "$roadmap" && -n "$phase" ]] || usage_error "$usage"
[[ "$phase" =~ ^[0-9]+$ ]] || usage_error "$usage"
[[ -f "$roadmap" ]] || { echo "roadmap not found: $roadmap" >&2; exit 2; }

count="$(tr -d '\r' <"$roadmap" | grep -cE '^## Phase [0-9]+([^0-9]|$)' || true)"
tr -d '\r' <"$roadmap" | grep -qE "^## Phase $phase([^0-9]|\$)" \
    || { echo "no '## Phase $phase' heading in $roadmap" >&2; exit 2; }

echo "ROADMAP $roadmap phase $phase of $count"
tr -d '\r' <"$roadmap" | awk -v n="$phase" '
    /^## / {
        seen = 1
        want = ($0 ~ ("^## Phase " n "([^0-9]|$)")) ? 1 : 0
    }
    !seen || want { print }
'

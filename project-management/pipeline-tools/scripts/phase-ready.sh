#!/usr/bin/env bash
# Prints what the supervisor needs to run a phase, from the ledger and the step files'
# routing fields alone, so the step files' context and actions (the worker's) and the
# other phases' notes never enter the supervisor's context.
#
# Usage: phase-ready.sh --repo <r> --plan <p> --phase <N> --ledger <repo-relative path>
#
# Prints:
#   PLAN working-branch=<b> current-phase=<n> artifacts-dir=<d>
#   PHASE <N> steps=<n> done=<d> pending=<p>
#   READY <id> route=<r> tier=<t> ancestors=<sha>[,<sha>...] or none   (launch now)
#   WAITING <id> on=<id>[,<id>...]                                      (dependencies not done)
#   DONE <id> <commit>
#   OTHER <id> <status>                                                 (failed, superseded, removed)
#   NOTES                                                               (then the phase's notes blocks, verbatim)
# A step is READY when it is pending and every depends_on id is `done` in the ledger;
# its ancestors are those dependencies' ledger commits, for wave-create.sh --ancestor.
# Exit 2 on usage, a missing ledger, or a pending step whose step file is missing.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="." plan="" phase="" ledger=""
usage="phase-ready.sh --repo <r> --plan <p> --phase <N> --ledger <path>"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --plan) plan="$2"; shift 2 ;;
        --phase) phase="$2"; shift 2 ;;
        --ledger) ledger="$2"; shift 2 ;;
        *) usage_error "$usage" ;;
    esac
done
[[ -n "$plan" && -n "$phase" && -n "$ledger" ]] || usage_error "$usage"
ledger_path="$repo/$ledger"
[[ -f "$ledger_path" ]] || { echo "ledger not found: $ledger_path" >&2; exit 2; }
adir="$(dirname "$ledger")"
text="$(tr -d '\r' <"$ledger_path")"

plan_field() { sed -n "s/^- $1: *//p" <<<"$text" | head -n 1; }
echo "PLAN working-branch=$(plan_field working-branch) current-phase=$(plan_field current-phase) artifacts-dir=$(plan_field artifacts-dir)"

# id|phase|status|commit for every Steps row
rows="$(awk -F'|' '
    /^## Steps/ { in_steps = 1; next }
    in_steps && /^## / { in_steps = 0 }
    in_steps && /^\|/ {
        for (i = 2; i <= 6; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
        if ($2 != "" && $2 != "id" && $2 !~ /^-+$/) print $2 "|" $3 "|" $4 "|" $6
    }' <<<"$text")"

declare -A status commit
ids=()
while IFS='|' read -r id ph st sha; do
    [[ -z "$id" ]] && continue
    status[$id]="$st"; commit[$id]="$sha"
    [[ "$ph" == "$phase" ]] && ids+=("$id")
done <<<"$rows"

n_done=0 n_pending=0 lines=()
for id in "${ids[@]+"${ids[@]}"}"; do
    case "${status[$id]}" in
        done) n_done=$((n_done + 1)); lines+=("DONE $id ${commit[$id]}") ;;
        pending)
            n_pending=$((n_pending + 1))
            f="$repo/$adir/$plan-$id.md"
            [[ -f "$f" ]] || { echo "step file not found for pending step $id: $adir/$plan-$id.md" >&2; exit 2; }
            route="$(step_scalar "$f" route)"; tier="$(step_scalar "$f" tier)"
            waiting="" ancestors=""
            while IFS= read -r dep; do
                [[ -z "$dep" ]] && continue
                if [[ "${status[$dep]:-}" == "done" ]]; then
                    ancestors+="${ancestors:+,}${commit[$dep]}"
                else
                    waiting+="${waiting:+,}$dep"
                fi
            done <<<"$(step_scalar "$f" depends_on | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)"
            if [[ -n "$waiting" ]]; then
                lines+=("WAITING $id on=$waiting")
            else
                lines+=("READY $id route=${route:-mechanical} tier=${tier:-standard} ancestors=${ancestors:-none}")
            fi ;;
        *) lines+=("OTHER $id ${status[$id]}") ;;
    esac
done

echo "PHASE $phase steps=${#ids[@]} done=$n_done pending=$n_pending"
for l in "${lines[@]+"${lines[@]}"}"; do echo "$l"; done
echo "NOTES"
awk -v n="$phase" '
    /^#/ { on = ($0 ~ ("^### Phase " n " (revision )?notes")) ? 1 : 0 }
    on { print }
' <<<"$text"

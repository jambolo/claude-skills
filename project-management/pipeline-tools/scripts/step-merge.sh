#!/usr/bin/env bash
# Records a verified step: merges its worktree branch into the current branch, updates
# the step's row in the ledger's Steps table (status, files, commit, cost columns),
# commits the ledger, and removes the worktree and its branch.
#
# Usage:
#   step-merge.sh --repo <path> --plan <plan-name> --id <id> --ledger <path> \
#                 (--worktree <path> | --in-tree) [--status done|failed] \
#                 [--tokens <n|n/a>] [--tool-uses <n|n/a>] [--wall <s|n/a>] [--retries <n>]
#
# --status done (default): merge (merge commit "merge(<plan>): step <id>"), then record.
# --status failed: no merge; the row records status failed, blank files and commit,
#                  and the cost columns; the worktree (if any) is discarded.
# <ledger> is relative to the repository root.
#
# Prints:
#   MERGED <id> <sha>        (status done; sha = the merge commit, or the step's own
#                             commit for --in-tree)
#   RECORDED <id> <status>
# Exit 0 on success, 1 on failure (first line "FAIL: ..."; a merge conflict is aborted
# and the worktree left in place), 2 on usage or a ledger row that cannot be found.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="" plan="" id="" ledger="" wt="" in_tree=0 status="done"
tokens="n/a" tool_uses="n/a" wall="n/a" retries="0"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --plan) plan="$2"; shift 2 ;;
        --id) id="$2"; shift 2 ;;
        --ledger) ledger="$2"; shift 2 ;;
        --worktree) wt="$2"; shift 2 ;;
        --in-tree) in_tree=1; shift ;;
        --status) status="$2"; shift 2 ;;
        --tokens) tokens="$2"; shift 2 ;;
        --tool-uses) tool_uses="$2"; shift 2 ;;
        --wall) wall="$2"; shift 2 ;;
        --retries) retries="$2"; shift 2 ;;
        *) usage_error "step-merge.sh --repo <path> --plan <name> --id <id> --ledger <path> (--worktree <path> | --in-tree) [--status done|failed] [--tokens n] [--tool-uses n] [--wall s] [--retries n]" ;;
    esac
done
[[ -n "$repo" && -n "$plan" && -n "$id" && -n "$ledger" ]] ||
    usage_error "step-merge.sh --repo <path> --plan <name> --id <id> --ledger <path> (--worktree <path> | --in-tree) ..."
[[ -n "$wt" || $in_tree -eq 1 ]] || usage_error "step-merge.sh: give --worktree <path> or --in-tree"
[[ "$status" == "done" || "$status" == "failed" ]] || usage_error "step-merge.sh: --status must be done or failed"

repo="$(cd "$repo" && pwd)"
branch="wt/$plan-$id"
ledger_path="$repo/$ledger"
[[ -f "$ledger_path" ]] || { echo "ledger not found: $ledger_path" >&2; exit 2; }

# The row must exist before anything irreversible happens.
if ! awk -v id="$id" '
        /^## Steps/ { in_steps = 1; next }
        in_steps && /^## / { in_steps = 0 }
        in_steps && /^\|/ {
            n = split($0, c, "|"); v = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", v)
            if (v == id) { found = 1; exit }
        }
        END { exit found ? 0 : 1 }
    ' "$ledger_path"; then
    echo "no row for step $id in the Steps table of $ledger" >&2
    exit 2
fi

sha="" files=""
if [[ "$status" == "done" ]]; then
    if [[ $in_tree -eq 1 ]]; then
        sha="$(git -C "$repo" rev-parse HEAD)"
        files="$(git -C "$repo" diff --name-only "HEAD~1..HEAD" | tr -d '\r' | paste -sd, - | sed 's/,/, /g')"
    else
        before="$(git -C "$repo" rev-parse HEAD)"
        if ! git -C "$repo" merge --no-ff --no-edit -m "merge($plan): step $id" "$branch" >/dev/null 2>&1; then
            conflicts="$(git -C "$repo" diff --name-only --diff-filter=U | tr -d '\r' | paste -sd, -)"
            git -C "$repo" merge --abort >/dev/null 2>&1 || true
            die "merge conflict in: ${conflicts:-unknown}; co-parallel scopes overlapped (decomposition bug) — merge aborted, worktree left for inspection"
        fi
        sha="$(git -C "$repo" rev-parse HEAD)"
        files="$(git -C "$repo" diff --name-only "$before..HEAD" | tr -d '\r' | paste -sd, - | sed 's/,/, /g')"
    fi
fi

short="${sha:0:12}"
tmp="$(mktemp)"
awk -v id="$id" -v st="$status" -v files="$files" -v sha="$short" \
    -v tokens="$tokens" -v tool_uses="$tool_uses" -v wall="$wall" -v retries="$retries" '
    /^## Steps/ { in_steps = 1 }
    in_steps && /^## / && !/^## Steps/ { in_steps = 0 }
    in_steps && /^\|/ && !done_row {
        n = split($0, c, "|"); v = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", v)
        if (v == id) {
            phase = c[3]; gsub(/^[ \t]+|[ \t]+$/, "", phase)
            print "| " id " | " phase " | " st " | " files " | " sha " | " tokens " | " tool_uses " | " wall " | " retries " |"
            done_row = 1
            next
        }
    }
    { print }
' "$ledger_path" >"$tmp"
mv "$tmp" "$ledger_path"

git -C "$repo" add -- "$ledger"
git -C "$repo" commit -q -m "supervise($plan): record step $id" -- "$ledger"

# Cleanup belongs to the worktree case only; an in-tree step has no wt/ branch, and a
# branch still checked out elsewhere is never touched.
if [[ -n "$wt" ]]; then
    git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true
    git -C "$repo" worktree prune
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" &&
       ! git -C "$repo" worktree list --porcelain | grep -qx "branch refs/heads/$branch"; then
        git -C "$repo" branch -D "$branch" >/dev/null
    fi
fi

[[ "$status" == "done" ]] && echo "MERGED $id $sha"
echo "RECORDED $id $status"

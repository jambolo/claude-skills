#!/usr/bin/env bash
# Creates one git worktree per step for a wave, all at the working branch's current HEAD
# (BASE), after gating that every dependency commit is already in BASE.
#
# Usage:
#   wave-create.sh --repo <path> --plan <plan-name> --worktrees <dir> \
#                  [--ancestor <sha>]... <id>...
#
# Prints, on success:
#   BASE <sha>
#   WORKTREE <id> <absolute path>        (one per id)
#   RECREATED <id>                       (when a stale worktree or branch was replaced)
# Exit 0 on success, 1 on a gate failure (first line "FAIL: ..."), 2 on usage.
#
# Refuses a dirty working tree: commit the ledger and any artifact edits first.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="" plan="" wtdir=""
ancestors=()
ids=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --plan) plan="$2"; shift 2 ;;
        --worktrees) wtdir="$2"; shift 2 ;;
        --ancestor) ancestors+=("$2"); shift 2 ;;
        --*) usage_error "wave-create.sh --repo <path> --plan <name> --worktrees <dir> [--ancestor <sha>]... <id>..." ;;
        *) ids+=("$1"); shift ;;
    esac
done
[[ -n "$repo" && -n "$plan" && -n "$wtdir" && ${#ids[@]} -gt 0 ]] ||
    usage_error "wave-create.sh --repo <path> --plan <name> --worktrees <dir> [--ancestor <sha>]... <id>..."

repo="$(cd "$repo" && pwd)"
if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    die "working tree is dirty; commit the ledger and artifact edits before creating a wave"
fi

base="$(git -C "$repo" rev-parse HEAD)"
for sha in "${ancestors[@]+"${ancestors[@]}"}"; do
    if ! git -C "$repo" cat-file -e "$sha^{commit}" 2>/dev/null; then
        die "dependency commit $sha does not exist in the repository"
    fi
    if ! git -C "$repo" merge-base --is-ancestor "$sha" "$base"; then
        die "dependency commit $sha is not an ancestor of BASE $base; repair the merge or ledger state"
    fi
done

mkdir -p "$wtdir"
wtdir="$(cd "$wtdir" && pwd)"

echo "BASE $base"
for id in "${ids[@]}"; do
    path="$wtdir/$plan-$id"
    branch="wt/$plan-$id"
    recreated=0
    if git -C "$repo" worktree list --porcelain | grep -qx "worktree $path"; then
        git -C "$repo" worktree remove --force "$path"
        recreated=1
    elif [[ -e "$path" ]]; then
        rm -rf "$path"
        recreated=1
    fi
    git -C "$repo" worktree prune
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$repo" branch -D "$branch" >/dev/null
        recreated=1
    fi
    git -C "$repo" worktree add "$path" -b "$branch" "$base" >/dev/null 2>&1
    head="$(git -C "$path" rev-parse HEAD)"
    if [[ "$head" != "$base" ]]; then
        die "worktree $path is at $head, not BASE $base"
    fi
    [[ $recreated -eq 1 ]] && echo "RECREATED $id"
    echo "WORKTREE $id $path"
done

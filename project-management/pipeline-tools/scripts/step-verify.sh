#!/usr/bin/env bash
# Verifies one step's result against ground truth, independently of the worker's report:
#   1. exactly one commit since BASE and a clean tree;
#   2. every changed path is in the step's files_in_scope, and the report is among them;
#   3. acceptance_cmd, run with bash from the worktree root, satisfies acceptance_expect.
#
# Usage:
#   step-verify.sh --worktree <path> --base <sha> --step <step-file> [--in-tree]
#
# Prints a verdict first, then the evidence:
#   VERDICT PASS | VERDICT FAIL
#   REASON <text>                        (one per failed check)
#   COMMITS <n>
#   CHANGED <path>                       (one per changed path)
#   ACCEPTANCE exit=<n> expect=<exact|exit 0>
#   --- acceptance output (last 40 lines) ---
# Exit 0 on PASS, 1 on FAIL, 2 on usage or an unparsable step file.
# --in-tree only documents that the worktree is the main repository; the checks are the same.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

wt="" base="" step=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --worktree) wt="$2"; shift 2 ;;
        --base) base="$2"; shift 2 ;;
        --step) step="$2"; shift 2 ;;
        --in-tree) shift ;;
        *) usage_error "step-verify.sh --worktree <path> --base <sha> --step <step-file> [--in-tree]" ;;
    esac
done
[[ -n "$wt" && -n "$base" && -n "$step" ]] ||
    usage_error "step-verify.sh --worktree <path> --base <sha> --step <step-file> [--in-tree]"
[[ -f "$step" ]] || { echo "step file not found: $step" >&2; exit 2; }

scope="$(step_files_in_scope "$step")"
cmd="$(step_block "$step" acceptance_cmd)"
expect="$(step_block "$step" acceptance_expect)"
[[ -n "$scope" ]] || { echo "step file has no files_in_scope entries: $step" >&2; exit 2; }
[[ -n "$cmd" ]] || { echo "step file has no acceptance_cmd block: $step" >&2; exit 2; }
[[ -n "$expect" ]] || { echo "step file has no acceptance_expect block: $step" >&2; exit 2; }

reasons=()

commits="$(git -C "$wt" rev-list --count "$base..HEAD")"
if [[ "$commits" -ne 1 ]]; then
    reasons+=("expected exactly one commit since BASE, found $commits")
fi
if [[ -n "$(git -C "$wt" status --porcelain)" ]]; then
    reasons+=("working tree is not clean after the commit")
fi

changed="$(git -C "$wt" diff --name-only "$base..HEAD" | tr -d '\r')"
report="$(basename "${step%.md}")-report.md"
report_seen=0
while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if ! grep -qxF -- "$path" <<<"$scope"; then
        reasons+=("out of scope: $path")
    fi
    [[ "$(basename "$path")" == "$report" ]] && report_seen=1
done <<<"$changed"
if [[ $report_seen -eq 0 ]]; then
    reasons+=("report $report is not in the commit")
fi

run_check "$wt" "$cmd" "$expect"
if [[ $CHECK_PASS -ne 0 ]]; then
    if [[ "$expect" == "exit 0" ]]; then
        reasons+=("acceptance exited $CHECK_EXIT, expected 0")
    else
        reasons+=("acceptance stdout did not match (exit $CHECK_EXIT): got '$(first_line "$CHECK_STDOUT")'")
    fi
fi

if [[ ${#reasons[@]} -eq 0 ]]; then
    echo "VERDICT PASS"
    status=0
else
    echo "VERDICT FAIL"
    for r in "${reasons[@]}"; do echo "REASON $r"; done
    status=1
fi
echo "COMMITS $commits"
while IFS= read -r path; do [[ -n "$path" ]] && echo "CHANGED $path"; done <<<"$changed"
if [[ "$expect" == "exit 0" ]]; then
    echo "ACCEPTANCE exit=$CHECK_EXIT expect=exit 0"
else
    echo "ACCEPTANCE exit=$CHECK_EXIT expect=exact"
fi
echo "--- acceptance output (last 40 lines) ---"
printf '%s\n' "$CHECK_TAIL"
exit $status

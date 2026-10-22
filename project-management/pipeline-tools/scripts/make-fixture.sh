#!/usr/bin/env bash
# Creates a throwaway repository holding one of the fixtures.
#
# Usage: make-fixture.sh [--fixture <kind>] <target-dir>   (target must not exist, or be empty)
#
# Kinds:
#   smoke               (default) plan "smoke": two phases, four pre-written steps;
#                       exercises the supervisor and workers only.
#   smoke-undecomposed  the same plan without step files; the supervisor spawns the
#                       decomposer per phase.
#   mid                 plan "textstat": three phases, undecomposed, with one open
#                       design decision (a judgment step) in phase 2.
#   project             no plan: a repository with a `develop` branch and SYNOPSIS.md,
#                       for an interactive end-to-end run of the `lead-developer`
#                       skill (planner included). Not for bench-run.sh.
#
# Prints FIXTURE <path>, KIND <kind>, PLAN <plan-name>, BRANCH <branch>, PHASES <n>,
# STARTING_COMMIT <sha>, then the procedure.

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$here/../fixture"

kind="smoke"
target=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fixture) kind="$2"; shift 2 ;;
        *) target="$1"; shift ;;
    esac
done
[[ -n "$target" ]] || { echo "usage: make-fixture.sh [--fixture smoke|smoke-undecomposed|mid|project] <target-dir>" >&2; exit 2; }

case "$kind" in
    smoke)              plan=smoke;    branch=smoke-run;    phases=2; project="$fixture/smoke-project";   docs="$fixture/smoke-docs"; ledger="" ;;
    smoke-undecomposed) plan=smoke;    branch=smoke-run;    phases=2; project="$fixture/smoke-project";   docs="$fixture/smoke-docs"; ledger="$fixture/smoke-ledger-undecomposed.md" ;;
    mid)                plan=textstat; branch=textstat-run; phases=3; project="$fixture/mid-project";     docs="$fixture/mid-docs";   ledger="" ;;
    project)            plan=notes;    branch=develop;      phases=0; project="$fixture/project-project"; docs="";                    ledger="" ;;
    *) echo "unknown fixture kind: $kind" >&2; exit 2 ;;
esac

if [[ -e "$target" && -n "$(ls -A "$target" 2>/dev/null)" ]]; then
    echo "target exists and is not empty: $target" >&2
    exit 2
fi
mkdir -p "$target"
target="$(cd "$target" && pwd)"

git init -q "$target"
git -C "$target" config core.autocrlf false
git -C "$target" config user.name >/dev/null 2>&1 || git -C "$target" config user.name "pipeline-bench"
git -C "$target" config user.email >/dev/null 2>&1 || git -C "$target" config user.email "pipeline-bench@example.invalid"

cp -R "$project/." "$target/"
git -C "$target" add -A
git -C "$target" commit -q -m "$plan: initial project"
start="$(git -C "$target" rev-parse HEAD)"

if [[ "$kind" == "project" ]]; then
    # lead-developer requires an existing develop branch and never creates it.
    git -C "$target" checkout -q -b develop
    echo "FIXTURE $target"
    echo "KIND $kind"
    echo "PLAN $plan"
    echo "BRANCH develop"
    echo "PHASES 0"
    echo "STARTING_COMMIT $start"
    cat <<EOF

Next: open a Claude Code session in
  $target
(auto mode; Sonnet at medium effort is enough for the driver) and say
  Act as lead developer: plan this project from SYNOPSIS.md, treating it as the complete
  interview input and asking only what it leaves genuinely open, then execute the plan
  milestone by milestone.
Expected end state: both milestones done in the project ledger on develop, two
milestone squash commits and two archive/notes-m<n> tags, the project Definition of Done
passing via dod-run.sh, no milestone/ branches, no leftover worktrees.
EOF
    exit 0
fi

git -C "$target" checkout -q -b "$branch"
mkdir -p "$target/docs"
for f in "$docs"/*.md; do
    name="$(basename "$f")"
    # smoke-undecomposed: no step files, and the undecomposed ledger instead.
    if [[ -n "$ledger" ]]; then
        [[ "$name" =~ ^$plan-[0-9]+[a-z]\.md$ ]] && continue
        [[ "$name" == "$plan-ledger.md" ]] && f="$ledger"
    fi
    sed "s/@STARTING_COMMIT@/$start/" "$f" >"$target/docs/$name"
done
git -C "$target" add -A
if [[ -n "$ledger" || "$kind" == "mid" ]]; then
    git -C "$target" commit -q -m "plan($plan): brief, roadmap, ledger"
else
    git -C "$target" commit -q -m "plan($plan): brief, roadmap, ledger, phase 1 and 2 steps"
fi

echo "FIXTURE $target"
echo "KIND $kind"
echo "PLAN $plan"
echo "BRANCH $branch"
echo "PHASES $phases"
echo "STARTING_COMMIT $start"
cat <<EOF

Next: open a Claude Code session in
  $target
and say
  supervise phase 1 of $plan (artifacts-dir docs/, working branch $branch)
then the remaining phases in order (up to phase $phases). Expected end state: every
Phases row complete, every Steps row done with the cost columns filled, no leftover
worktrees (git worktree list) and no wt/ branches. bench-run.sh does this headless.
EOF

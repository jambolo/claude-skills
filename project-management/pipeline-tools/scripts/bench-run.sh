#!/usr/bin/env bash
# Runs the pipeline headless (claude -p) on a fixture under one configuration, as many
# times as asked, and appends one tab-separated row per run to a results file: cost,
# tokens by model, wall-clock, turns, the ledger's cost columns, retries, revisions, the
# project DoD verdict, and leftovers. This is the measurement the review's experiments
# X3 (effort), X4 (Sonnet supervisor), and X5 (Haiku lite worker) need.
#
# Usage:
#   bench-run.sh --config <label> [--fixture smoke|smoke-undecomposed|mid]
#                [--set <agent>.<field>=<value>]... [--repeat <n>] [--driver-model <alias>]
#                [--max-budget-usd <usd>] [--results <tsv>] [--agents-src <dir>]
#                [--keep] [--dry-run] [--yes]
#
#   --set overrides one frontmatter field (model, effort, maxTurns) of one pipeline agent
#         for this run only: a copy of the installed definition with the field rewritten is
#         placed in the fixture's .claude/agents/, which takes precedence over
#         ~/.claude/agents. Examples:
#           --set supervisor.model=sonnet            (X4)
#           --set decomposer.effort=medium --set supervisor.effort=medium   (X3)
#           --set worker-lite.model=sonnet           (X5 control: lite steps on Sonnet)
#   --driver-model   model of the claude -p session that spawns the supervisor; default
#                    haiku, so its cost is separable from the Sonnet workers' in the
#                    per-model breakdown.
#   --max-budget-usd cap per phase run (claude's --max-budget-usd); default 5.
#   --results        the TSV to append to; default ./bench-results.tsv (header written when
#                    the file is new).
#   --agents-src     where the installed agent definitions are read from for --set;
#                    default ~/.claude/agents.
#   --keep           keep the fixture directories (printed in the row's path column).
#   --dry-run        print the plan and the command template; run nothing.
#   --yes            required to run claude: every run spends money.
#
# Requires: claude on PATH (v2.1.259+ for --permission-prompts none), the pipeline agents
# installed under ~/.claude/agents, and the pipeline-tools skill installed at
# ~/.claude/skills/pipeline-tools. Each phase runs as
#   claude -p "<prompt>" --output-format json --model <driver> \
#          --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Agent" --permission-prompts none \
#          --max-budget-usd <usd>
# from the fixture directory; the raw JSON of every phase is kept beside the fixture in
# bench/phase<N>.json until cleanup (always, with --keep).

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"

config="" kind="smoke" repeat=1 driver="haiku" budget="5" results="./bench-results.tsv"
agents_src="$HOME/.claude/agents" keep=0 dry=0 yes=0
sets=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) config="$2"; shift 2 ;;
        --fixture) kind="$2"; shift 2 ;;
        --set) sets+=("$2"); shift 2 ;;
        --repeat) repeat="$2"; shift 2 ;;
        --driver-model) driver="$2"; shift 2 ;;
        --max-budget-usd) budget="$2"; shift 2 ;;
        --results) results="$2"; shift 2 ;;
        --agents-src) agents_src="$2"; shift 2 ;;
        --keep) keep=1; shift ;;
        --dry-run) dry=1; shift ;;
        --yes) yes=1; shift ;;
        *) usage_error "bench-run.sh --config <label> [--fixture kind] [--set agent.field=value]... [--repeat n] [--driver-model m] [--max-budget-usd u] [--results tsv] [--agents-src dir] [--keep] [--dry-run] [--yes]" ;;
    esac
done
[[ -n "$config" ]] || usage_error "bench-run.sh: --config <label> is required"
[[ "$config" != *$'\t'* ]] || usage_error "bench-run.sh: --config must not contain a tab"

sets_str="$(IFS=';'; echo "${sets[*]+"${sets[*]}"}")"
tools="Bash,Read,Write,Edit,Glob,Grep,Agent"
scripts_dir="$HOME/.claude/skills/pipeline-tools/scripts"

prompt_for() {
    local plan="$1" branch="$2" phase="$3"
    printf 'Supervise phase %s of plan %s: plan-name %s, artifacts-dir docs/, working branch %s. Spawn the `supervisor` agent (subagent_type: supervisor, run_in_background: false) with exactly those four facts and nothing else, wait for it, and make its final RESULT line the last line of your reply.' \
        "$phase" "$plan" "$plan" "$branch"
}

if [[ $dry -eq 1 ]]; then
    echo "DRY-RUN config=$config fixture=$kind repeat=$repeat driver=$driver budget=$budget results=$results"
    echo "SETS ${sets_str:-none}"
    echo "COMMAND (per phase, from the fixture directory):"
    echo "  claude -p \"$(prompt_for '<plan>' '<branch>' '<N>')\" --output-format json --model $driver --allowedTools \"$tools\" --permission-prompts none --max-budget-usd $budget"
    exit 0
fi

[[ $yes -eq 1 ]] || { echo "bench-run.sh: every run spends money; pass --yes to proceed (or --dry-run to see the plan)" >&2; exit 2; }
command -v claude >/dev/null || { echo "bench-run.sh: claude is not on PATH" >&2; exit 2; }
[[ -f "$scripts_dir/step-verify.sh" ]] || { echo "bench-run.sh: pipeline-tools is not installed at $scripts_dir" >&2; exit 2; }
for a in supervisor worker; do
    [[ -f "$agents_src/$a.md" ]] || { echo "bench-run.sh: agent $a is not installed in $agents_src" >&2; exit 2; }
done
for s in "${sets[@]+"${sets[@]}"}"; do
    agent="${s%%.*}"; rest="${s#*.}"; field="${rest%%=*}"; value="${rest#*=}"
    [[ -n "$agent" && -n "$field" && -n "$value" && "$rest" == *=* ]] || { echo "bench-run.sh: bad --set '$s' (want agent.field=value)" >&2; exit 2; }
    [[ -f "$agents_src/$agent.md" ]] || { echo "bench-run.sh: --set names agent '$agent', not installed in $agents_src" >&2; exit 2; }
    case "$field" in model|effort|maxTurns) ;; *) echo "bench-run.sh: --set field must be model, effort, or maxTurns" >&2; exit 2 ;; esac
done

# override_agent, extract_run, and ledger_stats come from lib.sh.

header=$'timestamp\tconfig\tfixture\trepeat\tsets\tphases_done\tphases\tdod\tcost_usd\tduration_s\tturns\tsteps_done\tsteps_total\ttokens_sum\ttool_uses_sum\twall_s_sum\tretries_sum\trevisions\tworktrees_left\tbranches_left\tmodels\tpath'
if [[ ! -f "$results" ]]; then
    printf '%s\n' "$header" >"$results"
fi

work="$(mktemp -d)"
for ((r = 1; r <= repeat; r++)); do
    path="$work/$config-$r"
    out="$(bash "$here/make-fixture.sh" --fixture "$kind" "$path")"
    plan="$(sed -n 's/^PLAN //p' <<<"$out")"
    branch="$(sed -n 's/^BRANCH //p' <<<"$out")"
    phases="$(sed -n 's/^PHASES //p' <<<"$out")"
    ledger="$path/docs/$plan-ledger.md"
    mkdir -p "$path/bench"
    if [[ ${#sets[@]} -gt 0 ]]; then
        mkdir -p "$path/.claude/agents"
        for s in "${sets[@]}"; do
            agent="${s%%.*}"; rest="${s#*.}"; field="${rest%%=*}"; value="${rest#*=}"
            src="$path/.claude/agents/$agent.md"
            [[ -f "$src" ]] || src="$agents_src/$agent.md"
            tmp="$path/.claude/agents/$agent.md.tmp"
            override_agent "$src" "$tmp" "$field" "$value"
            mv "$tmp" "$path/.claude/agents/$agent.md"
        done
        # The overrides are untracked repository content; keep the tree clean for wave-create.sh.
        printf '.claude/\nbench/\n' >>"$path/.git/info/exclude"
    else
        printf 'bench/\n' >>"$path/.git/info/exclude"
    fi

    phases_done=0 cost_total=0 duration_total=0 turns_total=0 models_all=""
    for ((p = 1; p <= phases; p++)); do
        prompt="$(prompt_for "$plan" "$branch" "$p")"
        json="$path/bench/phase$p.json"
        t0="$(date +%s)"
        set +e
        (cd "$path" && claude -p "$prompt" --output-format json --model "$driver" \
            --allowedTools "$tools" --permission-prompts none --max-budget-usd "$budget") \
            >"$json" 2>"$path/bench/phase$p.stderr"
        rc=$?
        set -e
        t1="$(date +%s)"
        fields="$(extract_run "$json")"
        IFS='|' read -r cost dur turns is_err last models <<<"$fields"
        [[ "$last" == "RESULT: done" ]] && phases_done=$((phases_done + 1))
        cost_total="$(awk -v a="$cost_total" -v b="${cost:-0}" 'BEGIN { printf "%.4f", a + b }')"
        duration_total=$((duration_total + t1 - t0))
        turns_total=$((turns_total + ${turns:-0}))
        models_all="${models_all:+$models_all;}phase$p:${models:-}"
        echo "RUN $config #$r phase $p: rc=$rc last='$last' cost=${cost:-?} wall=$((t1 - t0))s"
        [[ "$last" == "RESULT: done" ]] || break
    done

    set +e
    bash "$scripts_dir/dod-run.sh" --file "$path/docs/$plan-brief.md" --heading "Definition of Done (project)" --cwd "$path" >"$path/bench/dod.txt" 2>&1
    dod_rc=$?
    set -e
    dod="FAIL"; [[ $dod_rc -eq 0 ]] && dod="PASS"
    IFS='|' read -r s_done s_total tok tu wall ret rev <<<"$(ledger_stats "$ledger")"
    wt_left=$(( $(git -C "$path" worktree list | wc -l) - 1 ))
    br_left="$(git -C "$path" for-each-ref 'refs/heads/wt/' | wc -l | tr -d ' ')"
    keep_path=""
    [[ $keep -eq 1 ]] && keep_path="$path"
    printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)	$config	$kind	$r	${sets_str:-none}	$phases_done	$phases	$dod	$cost_total	$duration_total	$turns_total	$s_done	$s_total	$tok	$tu	$wall	$ret	$rev	$wt_left	$br_left	$models_all	$keep_path" >>"$results"
    echo "ROW $config #$r: phases_done=$phases_done/$phases dod=$dod cost=$cost_total duration=${duration_total}s retries=$ret revisions=$rev"
    if [[ $keep -eq 0 ]]; then
        git -C "$path" worktree prune >/dev/null 2>&1 || true
        rm -rf "$path"
    fi
done
[[ $keep -eq 0 ]] && rm -rf "$work"
echo "RESULTS $results"

#!/usr/bin/env bash
# Runs a fixture headless (claude -p) under one configuration, as many times as asked,
# and appends one tab-separated row per run to a results file: cost, tokens by model,
# wall-clock, turns, the ledger's cost columns, retries, revisions, the Definition of
# Done verdict, and leftovers. Three modes share the row format so they compare:
#
#   --mode supervise  (default; fixtures smoke, smoke-undecomposed, mid) one claude -p
#                     run per phase, each spawning the `supervisor` agent. The review's
#                     X3/X4/X5 experiments.
#   --mode lead       (fixture project) one claude -p run of the `lead-developer` skill
#                     from SYNOPSIS.md, pipeline agents included, with the interview
#                     suppressed. The pipeline arm of the X9 comparison.
#   --mode single     one claude -p session implements the fixture itself: no subagents
#                     (Agent tool disallowed), the chosen model and effort. On the project
#                     fixture it works from SYNOPSIS.md and is judged by the checks file;
#                     on a plan fixture (smoke, mid) it works from the committed brief and
#                     roadmap and is judged by the brief's project dod block, exactly as
#                     supervise mode is. The control arm of the X9 comparison.
#
# Usage:
#   bench-run.sh --config <label> [--mode supervise|lead|single] [--fixture <kind>]
#                [--set <agent>.<field>=<value>]... [--repeat <n>]
#                [--driver-model <alias>] [--driver-effort <level>]
#                [--max-budget-usd <usd>] [--results <tsv>] [--agents-src <dir>]
#                [--keep] [--dry-run] [--yes]
#
#   --set            overrides one frontmatter field (model, effort, maxTurns) of one
#                    pipeline agent for this run only: a copy of the installed definition
#                    with the field rewritten is placed in the fixture's .claude/agents/,
#                    which takes precedence over ~/.claude/agents. Modes supervise and
#                    lead only.
#   --driver-model   model of the claude -p session. In supervise mode it only spawns the
#                    supervisor (default haiku, so its cost is separable); in lead mode it
#                    IS the lead developer (default sonnet); in single mode it does all
#                    the work (default sonnet; run opus too).
#   --driver-effort  sets CLAUDE_CODE_EFFORT_LEVEL for the session (low|medium|high|...).
#   --max-budget-usd cap per claude run (claude's --max-budget-usd); default 5.
#   --results        the TSV to append to; default ./bench-results.tsv.
#   --agents-src     where installed agent definitions are read from for --set; default
#                    ~/.claude/agents.
#   --keep           keep the fixture directories (printed in the row's path column).
#   --dry-run        print the plan, the prompt, and the command; run nothing.
#   --yes            required to run claude: every run spends money.
#
# Row columns (tab-separated; bench-summary.sh reads them):
#   timestamp config fixture repeat sets phases_done phases dod cost_usd duration_s turns
#   steps_done steps_total tokens_sum tool_uses_sum wall_s_sum retries_sum revisions
#   worktrees_left branches_left models path
# In supervise mode phases/steps/tokens come from the plan ledger. In lead mode
# phases = milestones from the project ledger, steps and tool_uses/wall_s/retries/revisions
# are summed over the milestone ledgers (workers only), and tokens_sum is the session's
# modelUsage total (every model, subagents included). In single mode phases is 1 and
# counts the run as done when it exited cleanly, steps is the number of commits it made,
# and tokens_sum is the modelUsage total. dod is always the same checks file for a given
# fixture, so the arms are judged identically. The sets column records mode and driver.
#
# Requires: claude on PATH (v2.1.259+ for --permission-prompts none), the pipeline agents
# installed under ~/.claude/agents (supervise and lead modes), and the pipeline-tools
# skill at ~/.claude/skills/pipeline-tools. Raw JSON of every run stays in bench/ inside
# the fixture until cleanup.

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib.sh"
fixture_root="$here/../fixture"

config="" mode="supervise" kind="" repeat=1 driver="" effort="" budget="5" results="./bench-results.tsv"
agents_src="$HOME/.claude/agents" keep=0 dry=0 yes=0
sets=()
usage="bench-run.sh --config <label> [--mode supervise|lead|single] [--fixture kind] [--set agent.field=value]... [--repeat n] [--driver-model m] [--driver-effort e] [--max-budget-usd u] [--results tsv] [--agents-src dir] [--keep] [--dry-run] [--yes]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) config="$2"; shift 2 ;;
        --mode) mode="$2"; shift 2 ;;
        --fixture) kind="$2"; shift 2 ;;
        --set) sets+=("$2"); shift 2 ;;
        --repeat) repeat="$2"; shift 2 ;;
        --driver-model) driver="$2"; shift 2 ;;
        --driver-effort) effort="$2"; shift 2 ;;
        --max-budget-usd) budget="$2"; shift 2 ;;
        --results) results="$2"; shift 2 ;;
        --agents-src) agents_src="$2"; shift 2 ;;
        --keep) keep=1; shift ;;
        --dry-run) dry=1; shift ;;
        --yes) yes=1; shift ;;
        *) usage_error "$usage" ;;
    esac
done
[[ -n "$config" ]] || usage_error "bench-run.sh: --config <label> is required"
[[ "$config" != *$'\t'* ]] || usage_error "bench-run.sh: --config must not contain a tab"

case "$mode" in
    supervise)
        [[ -n "$kind" ]] || kind="smoke"
        [[ "$kind" != "project" ]] || usage_error "bench-run.sh: --mode supervise needs a plan fixture (smoke, smoke-undecomposed, mid)"
        [[ -n "$driver" ]] || driver="haiku"
        tools="Bash,Read,Write,Edit,Glob,Grep,Agent"; disallow="" ;;
    lead)
        [[ -n "$kind" ]] || kind="project"
        [[ "$kind" == "project" ]] || usage_error "bench-run.sh: --mode lead needs --fixture project"
        [[ -n "$driver" ]] || driver="sonnet"
        tools="Bash,Read,Write,Edit,Glob,Grep,Agent,Skill"; disallow="" ;;
    single)
        [[ -n "$kind" ]] || kind="project"
        [[ ${#sets[@]} -eq 0 ]] || usage_error "bench-run.sh: --set has no meaning in --mode single (no pipeline agents run)"
        [[ -n "$driver" ]] || driver="sonnet"
        tools="Bash,Read,Write,Edit,Glob,Grep"; disallow="Agent" ;;
    *) usage_error "bench-run.sh: --mode must be supervise, lead, or single" ;;
esac

sets_str="$(IFS=';'; echo "${sets[*]+"${sets[*]}"}")"
sets_col="mode=$mode;driver=$driver${effort:+/$effort}${sets_str:+;$sets_str}"
scripts_dir="$HOME/.claude/skills/pipeline-tools/scripts"
checks_file="$fixture_root/project-dod.txt"

prompt_supervise() {
    local plan="$1" branch="$2" phase="$3"
    printf 'Supervise phase %s of plan %s: plan-name %s, artifacts-dir docs/, working branch %s. Spawn the `supervisor` agent (subagent_type: supervisor, run_in_background: false) with exactly those four facts and nothing else, wait for it, and make its final RESULT line the last line of your reply.' \
        "$phase" "$plan" "$plan" "$branch"
}
prompt_lead() {
    printf '%s' 'Act as lead developer: plan this project from SYNOPSIS.md, treating it as the complete interview input, then execute the plan milestone by milestone. Nobody can answer questions in this session: where the synopsis is silent, choose the simplest option that satisfies it and record the choice in the project plan; never stop to ask. End your reply with the project ledger Milestones table.'
}
prompt_single() {
    # prompt_single <kind> <plan-name>
    if [[ "$1" == "project" ]]; then
        printf '%s' 'Implement the project described in SYNOPSIS.md in this repository, on the develop branch that is checked out. Plan briefly, write the code, and keep running the checks the synopsis lists under Definition of Done until every one passes exactly; commit your work. Nobody can answer questions in this session: where the synopsis is silent, choose the simplest option that satisfies it. Do not use subagents. End your reply with the output of each Definition of Done check.'
    else
        printf 'Implement the plan in docs/%s-brief.md and docs/%s-roadmap.md in this repository, on the branch that is checked out. Read both, plan briefly, write the code phase by phase, and keep running every item of every dod block in the roadmap and the brief until all pass exactly; commit your work. Do not edit the files in docs/. Nobody can answer questions in this session: where the plan is silent, choose the simplest option that satisfies it. Do not use subagents. End your reply with the output of each item of the brief'"'"'s Definition of Done (project).' "$2" "$2"
    fi
}

claude_cmd() {
    # Prints the claude command for the current mode (for --dry-run and the record).
    local p="$1"
    printf 'claude -p "%s" --output-format json --model %s --allowedTools "%s"%s --permission-prompts none --max-budget-usd %s' \
        "$p" "$driver" "$tools" "${disallow:+ --disallowedTools \"$disallow\"}" "$budget"
}

if [[ $dry -eq 1 ]]; then
    echo "DRY-RUN config=$config mode=$mode fixture=$kind repeat=$repeat driver=$driver${effort:+/$effort} budget=$budget results=$results"
    echo "MODE $mode"
    echo "SETS ${sets_str:-none}"
    case "$mode" in
        supervise) echo "COMMAND (per phase, from the fixture directory):"; echo "  $(claude_cmd "$(prompt_supervise '<plan>' '<branch>' '<N>')")" ;;
        lead)      echo "COMMAND (once, from the fixture directory):"; echo "  $(claude_cmd "$(prompt_lead)")" ;;
        single)    echo "COMMAND (once, from the fixture directory):"; echo "  $(claude_cmd "$(prompt_single "$kind" '<plan>')")" ;;
    esac
    [[ -n "$effort" ]] && echo "ENV CLAUDE_CODE_EFFORT_LEVEL=$effort"
    if [[ "$kind" == "project" ]]; then
        echo "DOD $checks_file"
    else
        echo "DOD docs/<plan>-brief.md (Definition of Done (project))"
    fi
    exit 0
fi

[[ $yes -eq 1 ]] || { echo "bench-run.sh: every run spends money; pass --yes to proceed (or --dry-run to see the plan)" >&2; exit 2; }
command -v claude >/dev/null || { echo "bench-run.sh: claude is not on PATH" >&2; exit 2; }
[[ -f "$scripts_dir/step-verify.sh" ]] || { echo "bench-run.sh: pipeline-tools is not installed at $scripts_dir" >&2; exit 2; }
if [[ "$mode" != "single" ]]; then
    for a in supervisor worker; do
        [[ -f "$agents_src/$a.md" ]] || { echo "bench-run.sh: agent $a is not installed in $agents_src" >&2; exit 2; }
    done
fi
for s in "${sets[@]+"${sets[@]}"}"; do
    agent="${s%%.*}"; rest="${s#*.}"; field="${rest%%=*}"; value="${rest#*=}"
    [[ -n "$agent" && -n "$field" && -n "$value" && "$rest" == *=* ]] || { echo "bench-run.sh: bad --set '$s' (want agent.field=value)" >&2; exit 2; }
    [[ -f "$agents_src/$agent.md" ]] || { echo "bench-run.sh: --set names agent '$agent', not installed in $agents_src" >&2; exit 2; }
    case "$field" in model|effort|maxTurns) ;; *) echo "bench-run.sh: --set field must be model, effort, or maxTurns" >&2; exit 2 ;; esac
done

# run_claude <fixture path> <prompt> <json out> <stderr out> → sets RUN_RC
run_claude() {
    local path="$1" p="$2" json="$3" err="$4"
    local -a cmd=(claude -p "$p" --output-format json --model "$driver" --allowedTools "$tools")
    [[ -n "$disallow" ]] && cmd+=(--disallowedTools "$disallow")
    cmd+=(--permission-prompts none --max-budget-usd "$budget")
    set +e
    if [[ -n "$effort" ]]; then
        (cd "$path" && CLAUDE_CODE_EFFORT_LEVEL="$effort" "${cmd[@]}") >"$json" 2>"$err"
    else
        (cd "$path" && "${cmd[@]}") >"$json" 2>"$err"
    fi
    RUN_RC=$?
    set -e
}

header=$'timestamp\tconfig\tfixture\trepeat\tsets\tphases_done\tphases\tdod\tcost_usd\tduration_s\tturns\tsteps_done\tsteps_total\ttokens_sum\ttool_uses_sum\twall_s_sum\tretries_sum\trevisions\tworktrees_left\tbranches_left\tmodels\tpath'
[[ -f "$results" ]] || printf '%s\n' "$header" >"$results"

work="$(mktemp -d)"
for ((r = 1; r <= repeat; r++)); do
    path="$work/$config-$r"
    out="$(bash "$here/make-fixture.sh" --fixture "$kind" "$path")"
    plan="$(sed -n 's/^PLAN //p' <<<"$out")"
    branch="$(sed -n 's/^BRANCH //p' <<<"$out")"
    phases="$(sed -n 's/^PHASES //p' <<<"$out")"
    start="$(sed -n 's/^STARTING_COMMIT //p' <<<"$out")"
    mkdir -p "$path/bench"
    printf 'bench/\n' >>"$path/.git/info/exclude"
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
        printf '.claude/\n' >>"$path/.git/info/exclude"
    fi

    phases_done=0 cost_total=0 duration_total=0 turns_total=0 models_all=""
    s_done=0 s_total=0 tok=0 tu=0 wall=0 ret=0 rev=0

    case "$mode" in
    supervise)
        for ((p = 1; p <= phases; p++)); do
            json="$path/bench/phase$p.json"
            t0="$(date +%s)"
            run_claude "$path" "$(prompt_supervise "$plan" "$branch" "$p")" "$json" "$path/bench/phase$p.stderr"
            t1="$(date +%s)"
            IFS='|' read -r cost dur turns is_err last models <<<"$(extract_run "$json")"
            [[ "$last" == "RESULT: done" ]] && phases_done=$((phases_done + 1))
            cost_total="$(awk -v a="$cost_total" -v b="${cost:-0}" 'BEGIN { printf "%.4f", a + b }')"
            duration_total=$((duration_total + t1 - t0))
            turns_total=$((turns_total + ${turns:-0}))
            models_all="${models_all:+$models_all;}phase$p:${models:-}"
            echo "RUN $config #$r phase $p: rc=$RUN_RC last='$last' cost=${cost:-?} wall=$((t1 - t0))s"
            [[ "$last" == "RESULT: done" ]] || break
        done
        set +e
        bash "$scripts_dir/dod-run.sh" --file "$path/docs/$plan-brief.md" --heading "Definition of Done (project)" --cwd "$path" >"$path/bench/dod.txt" 2>&1
        dod_rc=$?
        set -e
        IFS='|' read -r s_done s_total tok tu wall ret rev <<<"$(ledger_stats "$path/docs/$plan-ledger.md")"
        ;;
    lead)
        json="$path/bench/run.json"
        t0="$(date +%s)"
        run_claude "$path" "$(prompt_lead)" "$json" "$path/bench/run.stderr"
        t1="$(date +%s)"
        IFS='|' read -r cost dur turns is_err last models <<<"$(extract_run "$json")"
        cost_total="${cost:-0}"; duration_total=$((t1 - t0)); turns_total="${turns:-0}"; models_all="run:${models:-}"
        pl="$(ls "$path"/docs/*-project-ledger.md 2>/dev/null | head -n 1 || true)"
        if [[ -n "$pl" ]]; then
            IFS='|' read -r phases_done phases <<<"$(milestones_done "$pl")"
        else
            phases_done=0; phases=0
        fi
        IFS='|' read -r s_done s_total _ tu wall ret rev <<<"$(sum_ledgers "$path"/docs/*-m[0-9]*-ledger.md)"
        tok="$(models_total_tokens "${models:-}")"
        git -C "$path" checkout -q develop 2>/dev/null || true
        set +e
        bash "$scripts_dir/dod-run.sh" --checks "$checks_file" --cwd "$path" >"$path/bench/dod.txt" 2>&1
        dod_rc=$?
        set -e
        echo "RUN $config #$r lead: rc=$RUN_RC milestones=$phases_done/$phases cost=${cost:-?} wall=$((t1 - t0))s"
        ;;
    single)
        json="$path/bench/run.json"
        t0="$(date +%s)"
        run_claude "$path" "$(prompt_single "$kind" "$plan")" "$json" "$path/bench/run.stderr"
        t1="$(date +%s)"
        IFS='|' read -r cost dur turns is_err last models <<<"$(extract_run "$json")"
        cost_total="${cost:-0}"; duration_total=$((t1 - t0)); turns_total="${turns:-0}"; models_all="run:${models:-}"
        phases=1
        if [[ $RUN_RC -eq 0 && "${is_err,,}" != "true" ]]; then phases_done=1; fi
        s_done="$(git -C "$path" rev-list --count "$start..HEAD" 2>/dev/null || echo 0)"; s_total="$s_done"
        tok="$(models_total_tokens "${models:-}")"
        set +e
        if [[ "$kind" == "project" ]]; then
            bash "$scripts_dir/dod-run.sh" --checks "$checks_file" --cwd "$path" >"$path/bench/dod.txt" 2>&1
        else
            bash "$scripts_dir/dod-run.sh" --file "$path/docs/$plan-brief.md" --heading "Definition of Done (project)" --cwd "$path" >"$path/bench/dod.txt" 2>&1
        fi
        dod_rc=$?
        set -e
        echo "RUN $config #$r single: rc=$RUN_RC commits=$s_done cost=${cost:-?} wall=$((t1 - t0))s"
        ;;
    esac

    dod="FAIL"; [[ $dod_rc -eq 0 ]] && dod="PASS"
    wt_left=$(( $(git -C "$path" worktree list | wc -l) - 1 ))
    br_left="$(git -C "$path" for-each-ref 'refs/heads/wt/' 'refs/heads/milestone/' | wc -l | tr -d ' ')"
    keep_path=""
    [[ $keep -eq 1 ]] && keep_path="$path"
    printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)	$config	$kind	$r	$sets_col	$phases_done	$phases	$dod	$cost_total	$duration_total	$turns_total	$s_done	$s_total	$tok	$tu	$wall	$ret	$rev	$wt_left	$br_left	$models_all	$keep_path" >>"$results"
    echo "ROW $config #$r: phases_done=$phases_done/$phases dod=$dod cost=$cost_total duration=${duration_total}s retries=$ret revisions=$rev"
    if [[ $keep -eq 0 ]]; then
        git -C "$path" worktree prune >/dev/null 2>&1 || true
        rm -rf "$path"
    fi
done
[[ $keep -eq 0 ]] && rm -rf "$work"
echo "RESULTS $results"

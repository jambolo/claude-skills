#!/usr/bin/env bash
# Exercises every pipeline-tools script on the smoke fixture with the worker simulated in
# bash (no model involved). Exit 0 when every assertion holds.
#
# Usage: selftest.sh

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'cd /; rm -rf "$tmp"' EXIT
repo="$tmp/repo"
wts="$tmp/worktrees"
ledger="docs/smoke-ledger.md"
pass=0
fail=0

ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/     /'; }

# expect_out <desc> <needle> <cmd...>: stdout+stderr contains <needle>
expect_out() {
    local desc="$1" needle="$2"; shift 2
    local out
    out="$("$@" 2>&1 || true)"
    if grep -qF -- "$needle" <<<"$out"; then ok "$desc"; else bad "$desc" "$out"; fi
}
# expect_exit <desc> <code> <cmd...>
expect_exit() {
    local desc="$1" want="$2"; shift 2
    local out code=0
    out="$("$@" 2>&1)" || code=$?
    if [[ $code -eq $want ]]; then ok "$desc"; else bad "$desc (exit $code, wanted $want)" "$out"; fi
}

# Simulated worker: does step <id> in worktree <wt>, writes the report, commits once.
do_step() {
    local wt="$1" id="$2"
    case "$id" in
        1a) mkdir -p "$wt/src"; printf '#!/usr/bin/env bash\necho "hello, $1"\n' >"$wt/src/greet.sh" ;;
        1b) mkdir -p "$wt/src"; printf '#!/usr/bin/env bash\necho "$#"\n' >"$wt/src/count.sh" ;;
        2a) mkdir -p "$wt/test"
            printf '%s\n' '#!/usr/bin/env bash' \
                '[[ "$(bash src/greet.sh a)" == "hello, a" && "$(bash src/count.sh 1 2)" == "2" ]] && echo ok || { echo fail; exit 1; }' \
                >"$wt/test/run.sh" ;;
        2b) printf '\n## Usage\n\n    bash src/greet.sh <name>\n' >>"$wt/README.md" ;;
    esac
    write_report "$wt" "$id" pass
    git -C "$wt" add -A >/dev/null
    git -C "$wt" commit -q -m "step(smoke/$id): simulated"
}
write_report() {
    local wt="$1" id="$2" status="$3"
    cat >"$wt/docs/smoke-$id-report.md" <<EOF
- status: $status
- base: $(git -C "$wt" rev-parse HEAD)
- changes: simulated by selftest.sh
- acceptance: |
    simulated
- deviations: none
EOF
}

echo "== make-fixture"
expect_out "make-fixture prints FIXTURE" "FIXTURE $repo" bash "$here/make-fixture.sh" "$repo"
[[ "$(git -C "$repo" rev-parse --abbrev-ref HEAD)" == "smoke-run" ]] && ok "fixture is on smoke-run" || bad "fixture branch"
start="$(sed -n 's/^- starting-commit: //p' "$repo/$ledger")"
git -C "$repo" cat-file -e "$start^{commit}" && ok "ledger starting-commit is a real commit" || bad "starting-commit"

echo "== wave-create: phase 1"
out="$(bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" 1a 1b)"
base="$(sed -n 's/^BASE //p' <<<"$out")"
wt1a="$(sed -n 's/^WORKTREE 1a //p' <<<"$out")"
wt1b="$(sed -n 's/^WORKTREE 1b //p' <<<"$out")"
[[ -n "$base" && -d "$wt1a" && -d "$wt1b" ]] && ok "wave-create made two worktrees at BASE" || bad "wave-create phase 1" "$out"
[[ "$(git -C "$wt1a" rev-parse HEAD)" == "$base" ]] && ok "worktree HEAD equals BASE" || bad "worktree base"

echo "== step-verify: phase 1"
do_step "$wt1a" 1a
do_step "$wt1b" 1b
expect_out "1a verifies PASS" "VERDICT PASS" bash "$here/step-verify.sh" --worktree "$wt1a" --base "$base" --step "$wt1a/docs/smoke-1a.md"
expect_out "1b verifies PASS" "VERDICT PASS" bash "$here/step-verify.sh" --worktree "$wt1b" --base "$base" --step "$wt1b/docs/smoke-1b.md"
expect_exit "step-verify exits 0 on PASS" 0 bash "$here/step-verify.sh" --worktree "$wt1a" --base "$base" --step "$wt1a/docs/smoke-1a.md"

echo "== step-merge: phase 1"
expect_out "1a merges" "MERGED 1a" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 1a --ledger "$ledger" --worktree "$wt1a" --tokens 1200 --tool-uses 7 --wall 31 --retries 0
expect_out "1b merges" "MERGED 1b" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 1b --ledger "$ledger" --worktree "$wt1b" --tokens n/a --tool-uses 5 --wall 20 --retries 1
grep -qE '^\| 1a \| 1 \| done \| .*src/greet.sh.* \| [0-9a-f]{12} \| 1200 \| 7 \| 31 \| 0 \|$' "$repo/$ledger" && ok "ledger row 1a recorded with cost columns" || bad "ledger row 1a" "$(grep '^| 1a' "$repo/$ledger")"
grep -qE '^\| 1b \| 1 \| done \| .* \| [0-9a-f]{12} \| n/a \| 5 \| 20 \| 1 \|$' "$repo/$ledger" && ok "ledger row 1b recorded" || bad "ledger row 1b" "$(grep '^| 1b' "$repo/$ledger")"
[[ -z "$(git -C "$repo" status --porcelain)" ]] && ok "tree clean after merges" || bad "tree dirty after merges"
[[ ! -d "$wt1a" && ! -d "$wt1b" ]] && ok "worktrees removed" || bad "worktrees left behind"
! git -C "$repo" show-ref --verify --quiet refs/heads/wt/smoke-1a && ok "wt/ branch deleted" || bad "wt/ branch left behind"
sha1a="$(awk -F'|' '$2 ~ /^ *1a *$/ { gsub(/ /, "", $6); print $6 }' "$repo/$ledger")"
sha1b="$(awk -F'|' '$2 ~ /^ *1b *$/ { gsub(/ /, "", $6); print $6 }' "$repo/$ledger")"

echo "== dod-run: phase 1"
expect_out "phase 1 DoD passes" "DOD PASS 2/2" bash "$here/dod-run.sh" --file "$repo/docs/smoke-roadmap.md" --heading "Phase 1" --cwd "$repo"
expect_out "phase 2 DoD fails before phase 2" "DOD FAIL" bash "$here/dod-run.sh" --file "$repo/docs/smoke-roadmap.md" --heading "Phase 2" --cwd "$repo"
expect_exit "dod-run exits 1 on FAIL" 1 bash "$here/dod-run.sh" --file "$repo/docs/smoke-roadmap.md" --heading "Phase 2" --cwd "$repo"

echo "== wave-create gates"
git -C "$repo" checkout -q -b side
git -C "$repo" commit -q --allow-empty -m "side commit"
side="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" checkout -q smoke-run
expect_out "non-ancestor dependency refused" "not an ancestor" bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" --ancestor "$side" 2a
echo dirt >"$repo/dirt.txt"
expect_out "dirty tree refused" "dirty" bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" 2a
rm "$repo/dirt.txt"

echo "== wave-create: phase 2 with ancestors"
out="$(bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" --ancestor "$sha1a" --ancestor "$sha1b" 2a 2b)"
base2="$(sed -n 's/^BASE //p' <<<"$out")"
wt2a="$(sed -n 's/^WORKTREE 2a //p' <<<"$out")"
wt2b="$(sed -n 's/^WORKTREE 2b //p' <<<"$out")"
[[ -n "$base2" && -d "$wt2a" && -d "$wt2b" ]] && ok "phase 2 wave created" || bad "wave-create phase 2" "$out"
[[ -f "$wt2a/src/greet.sh" && -f "$wt2a/src/count.sh" ]] && ok "phase 2 worktrees contain phase 1 work" || bad "worktree base content"

echo "== step-verify negatives"
# out of scope
do_step "$wt2b" 2b
echo "# extra" >>"$wt2b/src/greet.sh"
git -C "$wt2b" commit -q -am "sneak"
expect_out "two commits rejected" "exactly one commit" bash "$here/step-verify.sh" --worktree "$wt2b" --base "$base2" --step "$wt2b/docs/smoke-2b.md"
git -C "$wt2b" reset -q --hard "$base2"
printf '\n## Usage\n\n    bash src/greet.sh <name>\n' >>"$wt2b/README.md"
echo "# extra" >>"$wt2b/src/greet.sh"
write_report "$wt2b" 2b pass
git -C "$wt2b" add -A; git -C "$wt2b" commit -q -m "step(smoke/2b): out of scope"
expect_out "out-of-scope change rejected" "out of scope: src/greet.sh" bash "$here/step-verify.sh" --worktree "$wt2b" --base "$base2" --step "$wt2b/docs/smoke-2b.md"
git -C "$wt2b" reset -q --hard "$base2"
# missing report
printf '\n## Usage\n\n    bash src/greet.sh <name>\n' >>"$wt2b/README.md"
git -C "$wt2b" add -A; git -C "$wt2b" commit -q -m "step(smoke/2b): no report"
expect_out "missing report rejected" "report smoke-2b-report.md is not in the commit" bash "$here/step-verify.sh" --worktree "$wt2b" --base "$base2" --step "$wt2b/docs/smoke-2b.md"
git -C "$wt2b" reset -q --hard "$base2"
# wrong output
mkdir -p "$wt2a/test"
printf '#!/usr/bin/env bash\necho okay\n' >"$wt2a/test/run.sh"
write_report "$wt2a" 2a pass
git -C "$wt2a" add -A; git -C "$wt2a" commit -q -m "step(smoke/2a): wrong output"
expect_out "wrong stdout rejected" "did not match" bash "$here/step-verify.sh" --worktree "$wt2a" --base "$base2" --step "$wt2a/docs/smoke-2a.md"
expect_exit "step-verify exits 1 on FAIL" 1 bash "$here/step-verify.sh" --worktree "$wt2a" --base "$base2" --step "$wt2a/docs/smoke-2a.md"
git -C "$wt2a" reset -q --hard "$base2"
# unparsable step file
printf '# Step x\n\n- id: x\n' >"$tmp/bad-step.md"
expect_exit "unparsable step file exits 2" 2 bash "$here/step-verify.sh" --worktree "$wt2a" --base "$base2" --step "$tmp/bad-step.md"

echo "== step-merge --status failed (in-tree, no git effect)"
expect_out "failed row recorded" "RECORDED 2b failed" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 2b --ledger "$ledger" --in-tree --status failed --tokens 900 --tool-uses 9 --wall 40 --retries 2
grep -qE '^\| 2b \| 2 \| failed \|  \|  \| 900 \| 9 \| 40 \| 2 \|$' "$repo/$ledger" && ok "failed row has blank files/commit and cost columns" || bad "failed row" "$(grep '^| 2b' "$repo/$ledger")"
expect_exit "unknown step id exits 2" 2 bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 9z --ledger "$ledger" --in-tree --status failed

echo "== phase 2 for real"
# wave-create must recreate worktrees whose branches still exist (the ledger commit above moved HEAD).
out="$(bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" --ancestor "$sha1a" --ancestor "$sha1b" 2a 2b)"
base2="$(sed -n 's/^BASE //p' <<<"$out")"
grep -q "^RECREATED 2a" <<<"$out" && ok "stale worktree recreated" || bad "RECREATED missing" "$out"
do_step "$wt2a" 2a
do_step "$wt2b" 2b
expect_out "2a verifies PASS" "VERDICT PASS" bash "$here/step-verify.sh" --worktree "$wt2a" --base "$base2" --step "$wt2a/docs/smoke-2a.md"
expect_out "2b verifies PASS" "VERDICT PASS" bash "$here/step-verify.sh" --worktree "$wt2b" --base "$base2" --step "$wt2b/docs/smoke-2b.md"
expect_out "2a merges" "MERGED 2a" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 2a --ledger "$ledger" --worktree "$wt2a" --tokens 1500 --tool-uses 9 --wall 44
expect_out "2b merges" "MERGED 2b" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 2b --ledger "$ledger" --worktree "$wt2b" --tokens 800 --tool-uses 6 --wall 25
grep -qE '^\| 2b \| 2 \| done \|' "$repo/$ledger" && ok "failed row overwritten by done" || bad "2b row not done"
expect_out "phase 2 DoD passes" "DOD PASS 2/2" bash "$here/dod-run.sh" --file "$repo/docs/smoke-roadmap.md" --heading "Phase 2" --cwd "$repo"
expect_out "project DoD passes" "DOD PASS 4/4" bash "$here/dod-run.sh" --file "$repo/docs/smoke-brief.md" --heading "Definition of Done (project)" --cwd "$repo"
[[ "$(git -C "$repo" worktree list | wc -l)" -eq 1 ]] && ok "only the main worktree remains" || bad "worktrees remain" "$(git -C "$repo" worktree list)"

echo "== dod-run: checks file, manual items, exit 0 mode"
cat >"$tmp/checks.txt" <<'EOF'
# true exits zero
cmd: true
expect: exit 0
# false exits non-zero
cmd: false
expect: exit 0
# a person looks
manual: open the app and click around
EOF
expect_out "checks file: PASS line" "PASS true exits zero" bash "$here/dod-run.sh" --checks "$tmp/checks.txt"
expect_out "checks file: FAIL line" "FAIL false exits non-zero" bash "$here/dod-run.sh" --checks "$tmp/checks.txt"
expect_out "checks file: MANUAL line" "MANUAL a person looks: open the app" bash "$here/dod-run.sh" --checks "$tmp/checks.txt"
expect_out "checks file: summary counts manual" "DOD FAIL 1 of 2 failed 1 manual" bash "$here/dod-run.sh" --checks "$tmp/checks.txt"
expect_exit "missing heading exits 2" 2 bash "$here/dod-run.sh" --file "$repo/docs/smoke-roadmap.md" --heading "Phase 9" --cwd "$repo"

echo "== step-merge: merge conflict"
out="$(bash "$here/wave-create.sh" --repo "$repo" --plan smoke --worktrees "$wts" 1a 1b)"
wt1a="$(sed -n 's/^WORKTREE 1a //p' <<<"$out")"
wt1b="$(sed -n 's/^WORKTREE 1b //p' <<<"$out")"
echo "line from 1a" >>"$wt1a/README.md"; write_report "$wt1a" 1a pass; git -C "$wt1a" add -A; git -C "$wt1a" commit -q -m "step(smoke/1a): conflict a"
echo "line from 1b" >>"$wt1b/README.md"; write_report "$wt1b" 1b pass; git -C "$wt1b" add -A; git -C "$wt1b" commit -q -m "step(smoke/1b): conflict b"
expect_out "first conflicting step merges" "MERGED 1a" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 1a --ledger "$ledger" --worktree "$wt1a"
expect_out "second reports a conflict" "merge conflict in: README.md" bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 1b --ledger "$ledger" --worktree "$wt1b"
expect_exit "conflict exits 1" 1 bash "$here/step-merge.sh" --repo "$repo" --plan smoke --id 1b --ledger "$ledger" --worktree "$wt1b"
[[ -z "$(git -C "$repo" status --porcelain)" ]] && ok "merge aborted, tree clean" || bad "tree dirty after aborted merge"
[[ -d "$wt1b" ]] && ok "conflicting worktree left for inspection" || bad "conflicting worktree removed"
git -C "$repo" worktree remove --force "$wt1b"; git -C "$repo" branch -D wt/smoke-1b >/dev/null

echo "== find-formatter-gates"
fr="$tmp/fmt"; mkdir -p "$fr"
expect_out "no tools → NONE" "NONE" bash "$here/find-formatter-gates.sh" --repo "$fr" --artifacts-dir docs --pattern 'smoke-*.md'
echo '{}' >"$fr/.prettierrc"
expect_out "prettier detected, uncovered" "GATE prettier config=.prettierrc ignore=.prettierignore covered=no entry=docs/smoke-*.md" bash "$here/find-formatter-gates.sh" --repo "$fr" --artifacts-dir docs --pattern 'smoke-*.md'
echo 'docs/smoke-*.md' >"$fr/.prettierignore"
expect_out "prettier covered after entry" "covered=yes" bash "$here/find-formatter-gates.sh" --repo "$fr" --artifacts-dir docs --pattern 'smoke-*.md'
printf 'repos:\n  - repo: https://github.com/igorshubovych/markdownlint-cli\n    hooks:\n      - id: markdownlint\n' >"$fr/.pre-commit-config.yaml"
expect_out "pre-commit regex entry" 'entry=^docs/smoke-.*\.md$' bash "$here/find-formatter-gates.sh" --repo "$fr" --artifacts-dir docs --pattern 'smoke-*.md'
expect_out "root artifacts dir drops the prefix" "entry=smoke-*.md" bash "$here/find-formatter-gates.sh" --repo "$fr" --artifacts-dir . --pattern 'smoke-*.md'

echo "== ledger_stats on the finished smoke ledger"
source "$here/lib.sh"
stats="$(ledger_stats "$repo/$ledger")"
# 1a..2b done (the conflict test re-recorded 1a; 1b's conflict never recorded) → 4 done of 4.
[[ "$stats" == 4\|4\|* ]] && ok "ledger_stats counts 4 of 4 done" || bad "ledger_stats" "$stats"
IFS='|' read -r _ _ tok tu wall ret rev <<<"$stats"
[[ "$tu" -gt 0 && "$wall" -gt 0 ]] && ok "ledger_stats sums tool_uses and wall_s" || bad "ledger_stats sums" "$stats"
[[ "$rev" -eq 0 ]] && ok "ledger_stats counts no revisions" || bad "ledger_stats revisions" "$stats"

echo "== override_agent"
cat >"$tmp/agent.md" <<'EOF'
---
name: supervisor
version: 4.0.0
model: opus
effort: high
tools: Read, Bash
---

# Body
EOF
override_agent "$tmp/agent.md" "$tmp/agent-out.md" model sonnet
grep -qx 'model: sonnet' "$tmp/agent-out.md" && ok "override_agent rewrites model" || bad "override model" "$(cat "$tmp/agent-out.md")"
[[ "$(grep -c '^model:' "$tmp/agent-out.md")" -eq 1 ]] && ok "override_agent keeps one model line" || bad "override model count"
override_agent "$tmp/agent.md" "$tmp/agent-out2.md" maxTurns 40
grep -qx 'maxTurns: 40' "$tmp/agent-out2.md" && ok "override_agent inserts a missing field" || bad "override insert" "$(cat "$tmp/agent-out2.md")"
[[ "$(sed -n '1,/^---$/!p' "$tmp/agent-out2.md" | grep -c '^maxTurns:')" -eq 0 ]] || true
grep -qx '# Body' "$tmp/agent-out2.md" && ok "override_agent keeps the body" || bad "override body"

echo "== extract_run on a sample claude -p result"
cat >"$tmp/run.json" <<'EOF'
{"type":"result","is_error":false,"duration_ms":12345,"num_turns":7,"result":"Supervisor finished.\n\nRESULT: done\n","session_id":"abc","total_cost_usd":0.1234,"modelUsage":{"claude-opus-5-5":{"inputTokens":100,"outputTokens":50,"cacheReadInputTokens":900,"costUSD":0.1},"claude-haiku-5-5":{"inputTokens":10,"outputTokens":5,"costUSD":0.0001}}}
EOF
if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    fields="$(extract_run "$tmp/run.json")"
    [[ "$fields" == 0.1234\|12345\|7\|[Ff]alse\|RESULT:\ done\|* ]] && ok "extract_run reads cost, duration, turns, last line" || bad "extract_run fields" "$fields"
    grep -q 'claude-opus-5-5:in=100,cr=900,out=50,cost=0.1' <<<"$fields" && ok "extract_run flattens modelUsage" || bad "extract_run models" "$fields"
else
    echo "skip extract_run (neither jq nor python on PATH)"
fi

echo "== make-fixture kinds"
expect_out "smoke-undecomposed prints PHASES 2" "PHASES 2" bash "$here/make-fixture.sh" --fixture smoke-undecomposed "$tmp/und"
[[ ! -f "$tmp/und/docs/smoke-1a.md" ]] && ok "undecomposed fixture has no step files" || bad "undecomposed step files present"
[[ "$(ledger_stats "$tmp/und/docs/smoke-ledger.md")" == 0\|0\|* ]] && ok "undecomposed ledger has no step rows" || bad "undecomposed ledger rows"
expect_out "mid fixture prints PLAN textstat" "PLAN textstat" bash "$here/make-fixture.sh" --fixture mid "$tmp/mid"
expect_out "mid fixture prints PHASES 3" "PHASES 3" bash "$here/make-fixture.sh" --fixture mid "$tmp/mid2"
[[ "$(git -C "$tmp/mid" rev-parse --abbrev-ref HEAD)" == "textstat-run" ]] && ok "mid fixture is on textstat-run" || bad "mid branch"
grep -q "starting-commit: $(git -C "$tmp/mid" rev-parse HEAD~1)" "$tmp/mid/docs/textstat-ledger.md" && ok "mid ledger starting-commit is the project commit" || bad "mid starting-commit"
for h in "Phase 1" "Phase 2" "Phase 3"; do
    expect_exit "mid roadmap '$h' dod block parses and fails before work" 1 bash "$here/dod-run.sh" --file "$tmp/mid/docs/textstat-roadmap.md" --heading "$h" --cwd "$tmp/mid"
done
expect_exit "mid brief project dod block parses" 1 bash "$here/dod-run.sh" --file "$tmp/mid/docs/textstat-brief.md" --heading "Definition of Done (project)" --cwd "$tmp/mid"
expect_exit "unknown fixture kind exits 2" 2 bash "$here/make-fixture.sh" --fixture nope "$tmp/nope"

echo "== project fixture (lead-developer exercise)"
expect_out "project fixture prints KIND project" "KIND project" bash "$here/make-fixture.sh" --fixture project "$tmp/proj"
[[ "$(git -C "$tmp/proj" rev-parse --abbrev-ref HEAD)" == "develop" ]] && ok "project fixture is on develop" || bad "project branch"
git -C "$tmp/proj" show-ref --verify --quiet refs/heads/develop && ok "develop branch exists" || bad "develop missing"
[[ -f "$tmp/proj/SYNOPSIS.md" ]] && ok "project fixture has SYNOPSIS.md" || bad "SYNOPSIS.md missing"
[[ -d "$tmp/proj/docs" && -z "$(ls "$tmp/proj/docs")" ]] && ok "project fixture has an empty docs/" || bad "docs/ not empty"
[[ -z "$(git -C "$tmp/proj" status --porcelain)" ]] && ok "project fixture tree is clean" || bad "project tree dirty"
expect_out "project fixture prints the lead-developer prompt" "Act as lead developer" bash "$here/make-fixture.sh" --fixture project "$tmp/proj2"

echo "== bench-run and bench-summary without spending"
expect_out "bench-run --dry-run prints the command" "COMMAND (per phase" bash "$here/bench-run.sh" --config base --fixture mid --set supervisor.model=sonnet --dry-run
expect_out "bench-run --dry-run lists the sets" "SETS supervisor.model=sonnet" bash "$here/bench-run.sh" --config base --set supervisor.model=sonnet --dry-run
expect_exit "bench-run refuses to run without --yes" 2 bash "$here/bench-run.sh" --config base
expect_exit "bench-run requires --config" 2 bash "$here/bench-run.sh" --dry-run
expect_out "bench-run --mode lead prints the lead prompt" "Act as lead developer" bash "$here/bench-run.sh" --config lead --mode lead --dry-run
expect_out "bench-run --mode lead defaults to the project fixture" "fixture=project" bash "$here/bench-run.sh" --config lead --mode lead --dry-run
expect_out "bench-run --mode single disallows Agent" '--disallowedTools "Agent"' bash "$here/bench-run.sh" --config single --mode single --dry-run
expect_out "bench-run --mode single names the checks file" "DOD " bash "$here/bench-run.sh" --config single --mode single --dry-run
expect_out "bench-run --driver-effort sets the env" "ENV CLAUDE_CODE_EFFORT_LEVEL=medium" bash "$here/bench-run.sh" --config single --mode single --driver-model opus --driver-effort medium --dry-run
expect_exit "bench-run --mode single rejects --set" 2 bash "$here/bench-run.sh" --config single --mode single --set supervisor.model=sonnet --dry-run
expect_out "bench-run --mode single on mid works from the brief and roadmap" "docs/<plan>-brief.md and docs/<plan>-roadmap.md" bash "$here/bench-run.sh" --config single --mode single --fixture mid --dry-run
expect_out "bench-run --mode single on mid is judged by the brief's dod block" "DOD docs/<plan>-brief.md" bash "$here/bench-run.sh" --config single --mode single --fixture mid --dry-run
expect_out "bench-run --mode single on project uses the checks file" "project-dod.txt" bash "$here/bench-run.sh" --config single --mode single --dry-run
expect_exit "bench-run --mode supervise rejects the project fixture" 2 bash "$here/bench-run.sh" --config base --fixture project --dry-run
expect_exit "bench-run rejects an unknown mode" 2 bash "$here/bench-run.sh" --config x --mode nope --dry-run

echo "== project DoD checks file and lead-mode helpers"
expect_out "project-dod.txt parses: five records" "FAIL add appends two notes" bash "$here/dod-run.sh" --checks "$here/../fixture/project-dod.txt" --cwd "$tmp/proj"
expect_exit "project-dod.txt fails on the empty fixture" 1 bash "$here/dod-run.sh" --checks "$here/../fixture/project-dod.txt" --cwd "$tmp/proj"
cat >"$tmp/pl.md" <<'EOF'
# notes — Project Ledger

## Milestones

| # | Name | Status  | Branch | Merge commit | Notes |
| --: | --- | --- | --- | --- | --- |
| 1 | add-list | done | milestone/1-add-list (deleted) | 325b13e | tag archive/notes-m1 |
| 2 | search-docs | in-progress | milestone/2-search-docs | | |

## Events
EOF
[[ "$(milestones_done "$tmp/pl.md")" == "1|2" ]] && ok "milestones_done counts 1 of 2" || bad "milestones_done" "$(milestones_done "$tmp/pl.md")"
[[ "$(sum_ledgers "$repo/$ledger" "$repo/$ledger")" == 8\|8\|* ]] && ok "sum_ledgers adds two ledgers" || bad "sum_ledgers" "$(sum_ledgers "$repo/$ledger" "$repo/$ledger")"
[[ "$(models_total_tokens 'claude-opus-5-5:in=100,cr=900,out=50,cost=0.1;claude-haiku-5-5:in=10,cr=0,out=5,cost=0.0001')" == "1065" ]] && ok "models_total_tokens sums in+cr+out" || bad "models_total_tokens" "$(models_total_tokens 'a:in=1,cr=2,out=3,cost=0')"
cat >"$tmp/results.tsv" <<'EOF'
timestamp	config	fixture	repeat	sets	phases_done	phases	dod	cost_usd	duration_s	turns	steps_done	steps_total	tokens_sum	tool_uses_sum	wall_s_sum	retries_sum	revisions	worktrees_left	branches_left	models	path
2026-10-22T00:00:00Z	baseline	smoke	1	none	2	2	PASS	1.0000	100	10	4	4	4000	20	80	0	0	0	0	m
2026-10-22T00:00:00Z	baseline	smoke	2	none	2	2	PASS	3.0000	300	30	4	4	6000	24	90	2	1	0	0	m
2026-10-22T00:00:00Z	x4-sonnet-sup	smoke	1	supervisor.model=sonnet	2	2	FAIL	0.5000	50	5	3	4	1000	9	40	1	0	1	1	m
EOF
expect_out "bench-summary averages the baseline" "baseline                 smoke                   2     2.0000      200.0     100%" bash "$here/bench-summary.sh" "$tmp/results.tsv"
expect_out "bench-summary reports the variant's DoD rate" "x4-sonnet-sup            smoke                   1     0.5000       50.0       0%" bash "$here/bench-summary.sh" "$tmp/results.tsv"
expect_exit "bench-summary exits 2 on a missing file" 2 bash "$here/bench-summary.sh" "$tmp/none.tsv"

echo
echo "selftest: $pass passed, $fail failed"
[[ $fail -eq 0 ]]

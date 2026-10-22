# Shared helpers for the pipeline-tools scripts. Sourced, never executed.
#
# Step-file format the parsers rely on (see decomposer/AGENT.md, "The step schema"):
#   - <field>: <scalar>            top-level scalar, column 0
#   - <field>: |                   top-level block; its lines are indented 4 spaces
#       <line>
#   - files_in_scope:              list; entries are "    - <path>"
# A block or list runs until the next line that starts a top-level field.

# step_scalar <file> <field>  → the scalar's value, or nothing.
step_scalar() {
    sed -n "s/^- $2: *//p" "$1" | head -n 1 | tr -d '\r'
}

# step_block <file> <field>  → the block's lines with the 4-space indent removed.
step_block() {
    awk -v pat="^- $2:" '
        $0 ~ pat { on = 1; next }
        on && /^- [a-z_]+:/ { exit }
        on { sub(/^    /, ""); print }
    ' "$1" | tr -d '\r'
}

# step_files_in_scope <file>  → one repo-relative path per line.
step_files_in_scope() {
    step_block "$1" files_in_scope | sed -n 's/^[[:space:]]*-[[:space:]]*//p' | sed 's/[[:space:]]*$//' | grep -v '^$' || true
}

# run_check <cwd> <cmd> <expect>
# Runs <cmd> with bash in <cwd>. Sets CHECK_EXIT, CHECK_STDOUT (CR-stripped), CHECK_TAIL
# (last 40 lines of stdout+stderr) and CHECK_PASS (0 = pass, 1 = fail).
# <expect> is either the literal line "exit 0" (only the exit status matters) or the
# exact expected stdout; trailing newlines are ignored on both sides, exit must be 0.
run_check() {
    local cwd="$1" cmd="$2" expect="$3"
    local out err
    out="$(mktemp)"
    err="$(mktemp)"
    set +e
    (cd "$cwd" && bash -c "$cmd" >"$out" 2>"$err" </dev/null)
    CHECK_EXIT=$?
    set -e
    CHECK_STDOUT="$(tr -d '\r' <"$out")"
    CHECK_TAIL="$( { cat "$out"; cat "$err"; } | tr -d '\r' | tail -n 40)"
    rm -f "$out" "$err"
    local want
    want="$(printf '%s' "$expect" | tr -d '\r')"
    if [[ "$want" == "exit 0" ]]; then
        if [[ $CHECK_EXIT -eq 0 ]]; then CHECK_PASS=0; else CHECK_PASS=1; fi
    elif [[ $CHECK_EXIT -eq 0 && "$CHECK_STDOUT" == "$want" ]]; then
        CHECK_PASS=0
    else
        CHECK_PASS=1
    fi
}

# first_line_or_empty <text>  → the first 200 characters of its first line.
first_line() {
    printf '%s' "$1" | head -n 1 | cut -c1-200
}

die() {
    echo "FAIL: $*" >&2
    exit "${DIE_STATUS:-1}"
}

# ---- benchmark helpers (bench-run.sh, selftest.sh) ----

# override_agent <src.md> <dest.md> <field> <value>
# Copies an agent definition with one frontmatter field rewritten, or inserted before the
# closing --- when absent.
override_agent() {
    local src="$1" dest="$2" field="$3" value="$4"
    awk -v f="$field" -v v="$value" '
        BEGIN { fm = 0; done = 0 }
        /^---$/ { fm++; if (fm == 2 && !done) { print f ": " v; done = 1 } print; next }
        fm == 1 && !done && $0 ~ ("^" f ":") { print f ": " v; done = 1; next }
        { print }
    ' "$src" >"$dest"
}

# extract_run <claude -p json file>
# Prints: cost|duration_ms|turns|is_error|last-result-line|models
# models = <model>:in=<n>,cr=<n>,out=<n>,cost=<usd>;...  (from modelUsage when present)
extract_run() {
    local f="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -r '[(.total_cost_usd // ""), (.duration_ms // ""), (.num_turns // ""), (.is_error // ""),
                ((.result // "") | split("\n") | map(select(length > 0)) | last // ""),
                ((.modelUsage // {}) | to_entries
                  | map("\(.key):in=\(.value.inputTokens // 0),cr=\(.value.cacheReadInputTokens // 0),out=\(.value.outputTokens // 0),cost=\(.value.costUSD // 0)")
                  | join(";"))] | join("|")' "$f" 2>/dev/null && return 0
    fi
    local py
    py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
    if [[ -n "$py" ]]; then
        "$py" -I - "$f" <<'PY' && return 0
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
mu = d.get("modelUsage") or {}
models = ";".join(
    f"{k}:in={v.get('inputTokens', 0)},cr={v.get('cacheReadInputTokens', 0)},out={v.get('outputTokens', 0)},cost={v.get('costUSD', 0)}"
    for k, v in mu.items())
lines = [l for l in (d.get("result") or "").splitlines() if l.strip()]
print("|".join(str(x) for x in [d.get("total_cost_usd", ""), d.get("duration_ms", ""), d.get("num_turns", ""),
                                 d.get("is_error", ""), lines[-1] if lines else "", models]))
PY
    fi
    # Neither jq nor python: report what grep can find and keep the raw file.
    local cost
    cost="$(grep -o '"total_cost_usd":[0-9.]*' "$f" | head -n 1 | cut -d: -f2)"
    echo "${cost}|||||raw-json-only"
}

# ledger_stats <ledger.md>
# Prints: steps_done|steps_total|tokens_sum|tool_uses_sum|wall_s_sum|retries_sum|revisions
ledger_stats() {
    awk '
        /^## Steps/ { sec = "steps"; next }
        /^## Revisions/ { sec = "rev"; next }
        /^## / { sec = "" }
        sec == "steps" && /^\|/ {
            n = split($0, c, "|"); id = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", id)
            if (id == "id" || id ~ /^-+$/) next
            total++
            st = c[4]; gsub(/^[ \t]+|[ \t]+$/, "", st); if (st == "done") done++
            for (i = 7; i <= 10; i++) { v = c[i]; gsub(/^[ \t]+|[ \t]+$/, "", v); if (v ~ /^[0-9]+(\.[0-9]+)?$/) sum[i] += v }
        }
        sec == "rev" && /^\|/ {
            n = split($0, c, "|"); p = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", p)
            if (p ~ /^[0-9]+$/) rev++
        }
        END { printf "%d|%d|%d|%d|%d|%d|%d\n", done, total, sum[7], sum[8], sum[9], sum[10], rev }
    ' "$1"
}

usage_error() {
    echo "usage: $*" >&2
    exit 2
}

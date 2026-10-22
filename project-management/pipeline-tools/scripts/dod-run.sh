#!/usr/bin/env bash
# Runs a Definition of Done written as a ```dod block and prints one line per item.
#
# Usage:
#   dod-run.sh --file <markdown> [--heading <text>] [--cwd <dir>]
#   dod-run.sh --checks <file> [--cwd <dir>]
#
# --file/--heading: the first ```dod fenced block after the first Markdown heading line
#   containing <heading> (a literal substring, e.g. "Phase 2", "Milestone 3" or
#   "Definition of Done (project)"); without --heading, the first ```dod block in the
#   file. Fence indentation is ignored.
# --checks: a file holding the block's content directly.
# --cwd: where the commands run (default: the current directory).
#
# Block format, one record per item:
#   # <name>
#   cmd: <one shell line>
#   expect: <exact stdout>  |  expect: exit 0
#   # <name>
#   manual: <what a person must confirm>
#
# Prints:
#   PASS <name> | FAIL <name>: <why> | MANUAL <name>: <text>
#   DOD PASS <n>/<n> [<m> manual] | DOD FAIL <k> of <n> failed [<m> manual]
# Exit 0 when nothing failed (manual items do not fail), 1 otherwise, 2 on usage or
# when no block/records are found.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

file="" heading="" checks="" cwd="."
while [[ $# -gt 0 ]]; do
    case "$1" in
        --file) file="$2"; shift 2 ;;
        --heading) heading="$2"; shift 2 ;;
        --checks) checks="$2"; shift 2 ;;
        --cwd) cwd="$2"; shift 2 ;;
        *) usage_error "dod-run.sh (--file <markdown> [--heading <text>] | --checks <file>) [--cwd <dir>]" ;;
    esac
done
[[ -n "$file" || -n "$checks" ]] || usage_error "dod-run.sh (--file <markdown> [--heading <text>] | --checks <file>) [--cwd <dir>]"

if [[ -n "$checks" ]]; then
    [[ -f "$checks" ]] || { echo "checks file not found: $checks" >&2; exit 2; }
    block="$(tr -d '\r' <"$checks")"
else
    [[ -f "$file" ]] || { echo "file not found: $file" >&2; exit 2; }
    block="$(awk -v h="$heading" '
        BEGIN { armed = (h == "") ? 1 : 0 }
        !armed && /^[ \t]*#/ && index($0, h) > 0 { armed = 1; next }
        armed && !in_block && $0 ~ /^[ \t]*```dod[ \t]*$/ { in_block = 1; next }
        in_block && $0 ~ /^[ \t]*```[ \t]*$/ { exit }
        in_block { sub(/^[ \t]+/, ""); print }
    ' "$file" | tr -d '\r')"
fi
if [[ -z "$block" ]]; then
    if [[ -n "$heading" ]]; then
        echo "no \`\`\`dod block found after a line containing '$heading' in $file" >&2
    else
        echo "no \`\`\`dod block found" >&2
    fi
    exit 2
fi

total=0 failed=0 manual=0
name="" cmd="" expect="" man=""

flush() {
    [[ -z "$name" ]] && return
    total=$((total + 1))
    if [[ -n "$man" ]]; then
        manual=$((manual + 1))
        echo "MANUAL $name: $man"
    elif [[ -z "$cmd" || -z "$expect" ]]; then
        failed=$((failed + 1))
        echo "FAIL $name: record needs both cmd: and expect: (or manual:)"
    else
        run_check "$cwd" "$cmd" "$expect"
        if [[ $CHECK_PASS -eq 0 ]]; then
            echo "PASS $name"
        else
            failed=$((failed + 1))
            if [[ "$expect" == "exit 0" ]]; then
                echo "FAIL $name: exited $CHECK_EXIT, expected 0; last output line: '$(printf '%s' "$CHECK_TAIL" | tail -n 1 | cut -c1-200)'"
            else
                echo "FAIL $name: expected '$(first_line "$expect")', got exit $CHECK_EXIT stdout '$(first_line "$CHECK_STDOUT")'"
            fi
        fi
    fi
    name="" cmd="" expect="" man=""
}

while IFS= read -r line; do
    case "$line" in
        "# "*) flush; name="${line#\# }" ;;
        "cmd: "*) cmd="${line#cmd: }" ;;
        "expect: "*) expect="${line#expect: }" ;;
        "manual: "*) man="${line#manual: }" ;;
        *) ;;
    esac
done <<<"$block"
flush

if [[ $total -eq 0 ]]; then
    echo "the dod block holds no '# <name>' records" >&2
    exit 2
fi
suffix=""
[[ $manual -gt 0 ]] && suffix=" $manual manual"
if [[ $failed -eq 0 ]]; then
    echo "DOD PASS $((total - manual))/$((total - manual))$suffix"
    exit 0
fi
echo "DOD FAIL $failed of $((total - manual)) failed$suffix"
exit 1

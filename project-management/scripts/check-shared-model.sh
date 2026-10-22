#!/usr/bin/env bash
# Exits 1 when the "Shared model" section differs between the planner, decomposer, and
# supervisor AGENT.md files. The section is duplicated by design (each agent installs
# independently); this is the mechanical check that the copies are still identical.
#
# The compared span runs from the section heading to the `<!-- shared-model: end -->`
# marker, exclusive. Text after the marker is stage-specific and is not compared.
#
# Usage: check-shared-model.sh [--repo-root <dir>]

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--repo-root" ]]; then
    repo_root="$2"
fi

family="$repo_root/project-management"
agents=(planner decomposer supervisor)
heading='## Shared model (planner → decomposer → supervisor)'
end_marker='<!-- shared-model: end -->'

# Prints the lines from the heading up to the end marker, exclusive. Prints nothing when
# the heading is missing; prints everything after the heading when the marker is missing,
# which the caller reports.
section() {
    awk -v h="$heading" -v m="$end_marker" '
        $0 == h { on = 1 }
        on && $0 == m { exit }
        on { print }
    ' "$1"
}

has_marker() {
    grep -qF -- "$end_marker" "$1"
}

status=0
ref="${agents[0]}"
ref_file="$family/$ref/AGENT.md"
ref_text="$(section "$ref_file")"
if [[ -z "$ref_text" ]]; then
    echo "check-shared-model: heading '$heading' not found in $ref/AGENT.md" >&2
    exit 2
fi
if ! has_marker "$ref_file"; then
    echo "check-shared-model: end marker '$end_marker' not found in $ref/AGENT.md" >&2
    exit 2
fi

for name in "${agents[@]:1}"; do
    file="$family/$name/AGENT.md"
    if ! has_marker "$file"; then
        echo "check-shared-model: end marker '$end_marker' not found in $name/AGENT.md" >&2
        status=2
        continue
    fi
    text="$(section "$file")"
    if [[ "$text" != "$ref_text" ]]; then
        echo "check-shared-model: $name/AGENT.md differs from $ref/AGENT.md:" >&2
        diff <(printf '%s\n' "$ref_text") <(printf '%s\n' "$text") >&2 || true
        status=1
    fi
done

if [[ $status -eq 0 ]]; then
    echo "check-shared-model: Shared model identical across ${agents[*]}"
fi

# worker-lite is the worker on a smaller model: everything after the frontmatter must be
# byte-identical, so the two contracts cannot drift apart.
body() {
    awk 'f { print } /^---$/ { c++; if (c == 2) f = 1 }' "$1"
}
w_body="$(body "$family/worker/AGENT.md")"
l_body="$(body "$family/worker-lite/AGENT.md")"
if [[ -z "$w_body" || -z "$l_body" ]]; then
    echo "check-shared-model: could not read the body of worker/AGENT.md or worker-lite/AGENT.md" >&2
    exit 2
fi
if [[ "$w_body" != "$l_body" ]]; then
    echo "check-shared-model: worker-lite/AGENT.md body differs from worker/AGENT.md:" >&2
    diff <(printf '%s\n' "$w_body") <(printf '%s\n' "$l_body") >&2 || true
    status=1
else
    echo "check-shared-model: worker-lite body identical to worker"
fi
exit $status

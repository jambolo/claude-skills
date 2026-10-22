#!/usr/bin/env bash
# Summarizes a bench-run.sh results file per configuration: runs, mean cost, mean
# duration, DoD pass rate, mean phases done, mean retries, mean revisions, mean tokens.
#
# Usage: bench-summary.sh [<results.tsv>]      (default ./bench-results.tsv)
#
# Prints one line per config, then the decision rule reminder. Exit 2 when the file is
# missing or holds no rows.

set -euo pipefail
results="${1:-./bench-results.tsv}"
[[ -f "$results" ]] || { echo "results file not found: $results" >&2; exit 2; }

rows="$(awk -F'\t' 'NR > 1 && NF >= 20' "$results" | wc -l | tr -d ' ')"
[[ "$rows" -gt 0 ]] || { echo "no result rows in $results" >&2; exit 2; }

awk -F'\t' '
    NR == 1 { next }
    NF < 20 { next }
    {
        c = $2 "\t" $3
        n[c]++
        cost[c] += $9; dur[c] += $10; ph[c] += $6; phases[c] = $7
        if ($8 == "PASS") pass[c]++
        ret[c] += $17; rev[c] += $18; tok[c] += $14
    }
    END {
        printf "%-24s %-20s %4s %10s %10s %8s %10s %8s %8s %12s\n", "config", "fixture", "runs", "cost_usd", "dur_s", "dod%", "phases", "retries", "revs", "tokens"
        for (c in n) {
            split(c, k, "\t")
            printf "%-24s %-20s %4d %10.4f %10.1f %7.0f%% %7.2f/%s %8.2f %8.2f %12.0f\n",
                k[1], k[2], n[c], cost[c] / n[c], dur[c] / n[c], 100 * pass[c] / n[c], ph[c] / n[c], phases[c], ret[c] / n[c], rev[c] / n[c], tok[c] / n[c]
        }
    }
' "$results" | sort

cat <<'EOF'

Decision rule: adopt a configuration only when, on every fixture, its mean cost per
completed run is lower than the baseline's and its DoD pass rate, mean retries, and mean
revisions are not worse than the baseline's beyond the noise floor (the spread between
repeated baseline runs). Two or three repeats per configuration per fixture.
EOF

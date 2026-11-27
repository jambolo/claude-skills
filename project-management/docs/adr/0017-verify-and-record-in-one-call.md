# 0017. The supervisor verifies and records a step in one script call, and a PASS prints one line

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** 175539b

## Context

After each worker returned, the supervisor ran `step-verify.sh`, read its evidence (commit count, changed paths, acceptance output tail), then ran `step-merge.sh` in a second turn ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)). On a PASS the evidence is not acted on, and the second turn re-reads the supervisor's whole context.

## Decision

- `step-verify.sh --quiet` prints one line on a PASS: `VERDICT PASS commits=<n> changed=<n> acceptance=<exact|exit 0>`. A FAIL always prints the full evidence.
- `step-verify.sh --merge-on-pass --repo --plan --id --ledger [--tokens --tool-uses --wall --retries]` runs `step-merge.sh` itself on a PASS and prints its `MERGED` and `RECORDED` lines. On a FAIL nothing is merged or recorded.
- The supervisor uses both flags, one call per step, a whole returned wave in one command.
- "Check the check" (reading the diff when the acceptance is a count or pattern match) moves before the call, because the worktree is gone after the merge.

## Rationale

- m18 phase 3: 0.20 USD against 0.22 USD, one fewer turn, cache read down 12.5% with no overlap.
- m10 phase 2 with real builds: 15–17 supervisor turns against 19–20 and cache read down 19%, both without overlap. The cost effect there was inside the noise.
- The verdict is still the script's ([0002](0002-supervisor-verifies-against-ground-truth.md)); only the output and the number of calls changed.

## Consequences

- A PASS is merged before the supervisor sees any evidence. Anything the supervisor wants to inspect on a passing step must be inspected first.
- `step-verify.sh` now has a side effect when asked; without `--merge-on-pass` it behaves as before.

## Alternatives considered

- **Quiet output only**: saves tokens but not the second turn, which is where most of the saving is.
- **Merge inside the worker**: rejected; workers never touch the working branch ([0003](0003-supervisor-creates-worktrees-at-an-exact-base.md)).

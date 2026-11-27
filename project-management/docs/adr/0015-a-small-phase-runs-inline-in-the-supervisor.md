# 0015. A phase the planner marks `inline` skips the decomposer and the workers; the supervisor does it in one commit

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** c48f7d3

## Context

Every phase went through the same three hops however small it was: the decomposer wrote step files, the supervisor created worktrees, and workers did the work ([0001](0001-three-stages-cooperate-only-through-markdown-artifacts.md)). The last phase of a milestone is usually a documentation update of two or three files. On the Sdlx project's `implementation-m18` phase 3 that cost 1.08 USD, of which 0.85 USD was the decomposer describing edits the supervisor could have made itself.

## Decision

- A roadmap phase may carry `- **Mode:** inline`. The planner sets it when the phase is one unit of work, touches at most three listed files, and is fully proved by its `dod` block. The planner is also told to prefer "fewer, wider phases".
- `lead-developer` skips the decomposer for such a phase and spawns the supervisor directly.
- The supervisor's "Inline phase" section does the work itself in the main tree, commits `supervise(<plan>): phase <N> (inline)`, records it in the ledger as step `<N>.1`, runs the phase `dod`, and completes the phase.
- If the phase proves not to be inline (more files, design needed), the supervisor restores the tree and falls back to decomposition.

## Rationale

- Measured on m18 phase 3 (four runs per arm): 0.30 USD against 1.08 USD, 76 s against 198 s, with the changed documents byte-identical to the recorded result and the `dod` passing in every run. Re-measured on the merged branch: 0.28 USD.
- The ledger still gets a step row and a commit, so [0008](0008-ledger-rows-are-never-erased.md) and the cost columns hold.

## Consequences

- The supervisor writes project files in an inline phase, which it otherwise never does. The `dod` run is the only check; there is no `step-verify.sh` on someone else's work ([0002](0002-supervisor-verifies-against-ground-truth.md) is unchanged for decomposed phases).
- The saving depends on the planner marking phases. That half and the fallback path were not benchmarked; the benchmark hand-marked the roadmap.
- A roadmap gains an optional field that `lead-developer` and the supervisor both read.

## Alternatives considered

- **Let the supervisor decide at run time**: rejected; the decision belongs with the plan, where a person reads it, and `lead-developer` must know before choosing which agent to spawn.
- **A cheaper decomposer for small phases**: still pays the worktree and worker hops for a two-file edit.

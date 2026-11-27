# 0016. Registering steps, computing the ready set, and completing a phase are `pipeline-tools` scripts

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** 7eb8eaf, e79193f, ecb60b2

## Context

[0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md) moved worktrees, verification, merging and `dod` runs into scripts, but three bookkeeping jobs stayed in the prompts. The decomposer hand-wrote the ledger's Steps rows and the phase notes with the dependency graph, then committed. The supervisor read every step file and the whole ledger to work out which steps could launch, and hand-edited the ledger to mark a phase complete. Each is mechanical, and each cost model turns that re-read a large context.

## Decision

- `steps-register.sh` (decomposer): checks every step file (required fields, own report in scope, `depends_on` resolvable, no cycle, co-parallel `files_in_scope` disjoint), appends `pending` rows from `files_in_scope`, writes the phase notes block with the graph, `judgment` routes and `lite` tiers computed from the step files, appends the decomposer's own bullets, and with `--commit` makes the `decompose(<plan>): phase <N> steps` commit. `--revise --supersede <id>` covers the revise operation. A defect prints `DEFECT` lines and writes nothing.
- `phase-ready.sh` (supervisor): prints the plan fields, the phase summary, `READY <id> route= tier= ancestors=`, `WAITING <id> on=`, `DONE <id> <sha>`, and that phase's notes only.
- `phase-complete.sh` (supervisor): refuses while a step is pending or failed, marks the phase `complete`, advances `current-phase`, and commits `supervise(<plan>): phase <N> complete`.
- The agents never hand-write Steps rows, the graph, or those ledger fields. The one hand edit left is a `removed` row ([0008](0008-ledger-rows-are-never-erased.md)).

## Rationale

- Decomposer, `implementation-m10` phase 2 (four steps, code): 1.59 USD against 2.09 USD, no overlap between arms, about ten fewer tool calls. On the three-step documentation phase the decomposer saving was nil.
- Supervisor, m18 phase 3: median 0.17 USD against 0.22 USD. On m10 phase 2 the supervisor read 14% less from cache; the cost difference was under the noise because builds and workers dominate.
- Scope overlap and dependency cycles are now caught before the commit instead of at merge time.

## Consequences

- The step schema is parsed by three more scripts; schema changes need them and `selftest.sh` updated together.
- The decomposer's notes carry only what cannot be computed: couplings, bootstrap facts, emergent contracts.
- The supervisor no longer sees step bodies unless it opens one.

## Alternatives considered

- **Leave the notes free-form**: the graph in prose could disagree with `depends_on`, and nothing checked it.
- **One script for all three jobs**: rejected; they run in different agents at different times.

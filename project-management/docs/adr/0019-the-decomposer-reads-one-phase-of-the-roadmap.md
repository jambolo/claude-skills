# 0019. The decomposer reads its one phase of the roadmap through `phase-context.sh`

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** 55540ad

## Context

The decomposer handles one phase per run but read the whole roadmap, so every other phase's objective, risks and `dod` block sat in its context for every later turn ([0001](0001-three-stages-cooperate-only-through-markdown-artifacts.md)). The roadmap grows with the plan; the slice a phase needs does not.

## Decision

- `phase-context.sh --roadmap <md> --phase <N>` prints `ROADMAP <path> phase <N> of <count>`, the roadmap's preamble, and the one `## Phase <N>` section. It exits 2 when the heading is missing.
- The decomposer calls it instead of reading the roadmap file, and reads other files narrowly (the lines it needs, not whole files).

## Rationale

- Decomposer cost fell 12% on both benchmark phases (0.75 against 0.85 USD; 1.83 against 2.09 USD). The ranges overlap the baseline's at four runs per arm, so the size of the effect is uncertain, but it was the same in both rounds and the mechanism (fewer cached tokens re-read per turn) is direct.
- It costs one small script and removes nothing the decomposer uses.

## Consequences

- A fact the decomposer needs from another phase must be in the preamble, the brief, or the ledger's phase notes. That is where [0008](0008-ledger-rows-are-never-erased.md) already puts emergent contracts.
- The `## Phase <N>` heading format is now parsed ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)).

## Alternatives considered

- **Split the roadmap into one file per phase**: changes an artifact every stage reads, for the benefit of one.
- **Tell the decomposer to read a line range**: it would first have to find the range, which is the read being avoided.

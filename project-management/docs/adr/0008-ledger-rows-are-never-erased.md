# 0008. The ledger is a registry: a step that is dropped is marked `removed`, never erased, and each phase has a notes block

**Status:** Accepted
**Date:** 2026-07-27
**Commits:** fbc90c0, 5039ccd

## Context

The ledger is the one artifact all three stages write: the planner seeds it, the decomposer registers steps, the supervisor records results. e3ff846 called it "what makes the run resumable and what the `decomposer` reads when revising". The review of the four-in-a-row run found that a revision which made a step unnecessary simply deleted its row, and that there was no place to say why a phase's steps looked the way they did. fbc90c0:

> - Removed-step registry (finding 5): superfluous steps marked status=removed in the ledger with reason in phase notes, never erased.
> - Per-phase notes block in the ledger schema (finding 7), decomposer-owned.
> - files_in_scope entries are plain paths, no markdown (finding 8).

## Decision

- A step that a revision makes superfluous keeps its ledger row with `status: removed`; the reason goes in the phase's notes. Rows are never deleted.
- The ledger schema has a notes block per phase, owned by the decomposer.
- `files_in_scope` entries are plain paths with no backticks or other Markdown, because they are "compared literally".

## Rationale

The commit states the decisions and cites findings 5, 7, and 8 of the run review; it does not restate the review's reasoning. The surrounding design supplies the role the ledger plays: it must be "authoritative" and "truthful and current … so a run can resume exactly where it stopped".

## Consequences

- Step ids are stable for the life of a plan; an id that appears in a commit message or a revision row always resolves to a ledger row.
- The ledger grows monotonically within a plan.
- Since 5039ccd the Steps table's columns are parsed and rewritten by `step-merge.sh`, which also fills per-step cost columns (tokens, tool uses, wall time, retries); a change to the columns is a change to the script ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)).
- Plain-path `files_in_scope` is what lets `step-verify.sh` compare changed paths against scope by exact string.

## Alternatives considered

- **Delete the row of a dropped step** (before fbc90c0): the history of the decomposition was lost from the artifact that is supposed to hold it.

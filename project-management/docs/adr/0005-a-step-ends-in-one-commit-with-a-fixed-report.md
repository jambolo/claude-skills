# 0005. A step ends in exactly one commit that includes a fixed-schema report; a worker reports an unsatisfiable check, it never games it

**Status:** Accepted
**Date:** 2026-07-22
**Commits:** 61ac934, fbc90c0, 5cde06f

## Context

The first full run of the pipeline (the game-player `mcts-value-estimator` plan) was reviewed in a post-mortem (46b8e7a) that produced recommendations R1–R12. The worker contract until then (106acf1) told a worker to commit its changes and "then write `<plan-name>-<id>-report.md` … listing what you did, the exact acceptance output, your branch, and your commit SHA". 61ac934 applied the recommendations; its message lists the ones this ADR covers:

> - R1/R5: single-commit worker protocol with a fixed report schema, no self-referential commit SHA (new shared-model block, synced across all three)
> - R2: workers must stop and report unsatisfiable acceptance checks, never game them
> - R12: prefer plain file ops over git rm/mv in worker actions

## Decision

The Shared model gained a "Worker report & commit protocol":

> A step ends in exactly ONE commit containing every changed `files_in_scope` path — the report included, so the worker writes `<plan-name>-<id>-report.md` BEFORE committing.

The report has fixed fields — `status: pass | fail | missing-base`, `base`, `changes`, `acceptance` (command, exit code, last 40 lines of output), `deviations` — and "never contains its own commit SHA, branch, or anything else self-referential".

A worker that cannot make the acceptance check pass honestly stops and reports `fail`; it does not alter the check, the expected output, or files outside its scope to get a pass.

## Rationale

- "The supervisor reads commit identity from git, and a SHA recorded inside the commit it names cannot be written" (Shared model).
- One commit per step gives the supervisor a single thing to verify and merge; "one commit" is one of the three things it checks ([0002](0002-supervisor-verifies-against-ground-truth.md)).
- An acceptance check that cannot be satisfied is a defect in the step, to be fixed by revision; a gamed check hides it (R2).

## Consequences

- The report is a file in the step's scope and travels with the code in the same commit, so it is versioned and reachable later ([0004](0004-plan-artifacts-are-committed-as-the-plan-proceeds.md)).
- `status: fail` and `missing-base` are legitimate outcomes with their own handling, not errors in the worker.
- fbc90c0 (finding 9) pinned the worker's commit-message format alongside the merge and supervisor formats.
- When the stages became agents (5cde06f), the contract moved into the `worker` definition; the family `CLAUDE.md` requires it to "stay consistent with the 'Worker report & commit protocol' paragraph" in the Shared model, which the workers do not carry.
- The supervisor gained a matching failure option (R3, "Correct in flight") for a step whose specification is defective.

## Alternatives considered

- **Commit, then write a report naming the commit** (106acf1): the report was either uncommitted or needed a second commit, and the SHA field could not describe the commit that contained it.
- **Let the worker "fix within scope until it passes" without limit** (e3ff846 wording): replaced by stop-and-report for a check that cannot pass honestly.

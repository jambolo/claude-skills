# 0002. The supervisor verifies every step against ground truth and never trusts a worker's report

**Status:** Accepted
**Date:** 2026-07-04
**Commits:** e3ff846, 61ac934, 5039ccd

## Context

The pipeline's economics rest on cheap workers, and a cheap worker's account of its own work is the least reliable thing in the run. e3ff846 made distrust the supervisor's "core discipline":

> You execute a phase's steps by launching cheap-model workers, but you trust **nothing** they tell you. A worker's report is a lead, never evidence.

> Treat `<plan-name>-<id>-report.md` as a hint about what the worker *believes* it did — never as proof. Ground truth is the acceptance result and the diff.

It also fixed what a failure of the mechanics means:

> **A merge conflict is not something to hand-resolve** — it means two co-parallel steps overlapped in scope, which is a decomposition bug: roll back and send a revision note to the `decomposer`.

## Decision

For every step, independently of the report, the supervisor:

1. re-runs the step's acceptance check itself against the tree the worker produced and compares the result with the step's exact expected result;
2. confirms the changed paths are a subset of `files_in_scope`, and that the worktree holds no commit that is not this step's own work. An out-of-scope change fails the step even when acceptance passes.

A passing step is merged and recorded in the ledger; a failing step is retried (bounded), sent to the decomposer with a revision note, or escalated — "never loop indefinitely on the same step". A merge conflict is never hand-resolved; it goes back to the decomposer as a scoping defect. The phase's Definition of Done is likewise run by the supervisor, not taken from any step's report.

Every step therefore needs an acceptance check that a machine can run and compare: a command and its exact expected result.

## Rationale

- "A worker's report is a lead, never evidence"; "ground truth is the acceptance result and the diff" (supervisor).
- A merge conflict "means two co-parallel steps overlapped in scope, which is a decomposition bug", so the fix belongs to the decomposer, not to a hand merge.

## Consequences

- Every acceptance check runs at least twice (worker, then supervisor); a slow check is paid for twice.
- The decomposer carries the burden of writing checks that are exact and that "exercise every compile/test surface the change can break" (106acf1).
- The same rule applies one level up: a caller reads a stage's `RESULT:` line and then "verif[ies] ground truth (artifacts on disk, commits in `git log`) before acting on `done`" ([0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md)).
- Since 5039ccd the checks are a script's verdict, not the supervisor's own git commands: `step-verify.sh` prints `VERDICT PASS` or `VERDICT FAIL` ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)).
- 61ac934 (R7) added a re-verification of facts embedded in steps after parallel waves, and a third failure option for a defective step specification ("Correct in flight").

## Alternatives considered

- **Accept the worker's reported acceptance output**: rejected from the first version; the report is a hint.
- **Let the supervisor resolve merge conflicts**: rejected; it would hide a decomposition defect.

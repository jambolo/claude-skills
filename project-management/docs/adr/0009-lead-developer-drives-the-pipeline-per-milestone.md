# 0009. A `lead-developer` skill sits above the pipeline and runs it once per milestone, each on its own branch squash-merged into `develop`

**Status:** Accepted
**Date:** 2026-08-22
**Commits:** 0719e9c, 5cde06f, 5039ccd

## Context

The pipeline handles one bounded goal: a person invoked the planner, then the decomposer and supervisor per phase. A whole project is larger than that. 0719e9c ("Added `lead-developer` skill") added a stage for "a whole-project goal too large for a single planner run":

> A milestone is to you what a phase is to the planner: an ordered chunk with a checkable Definition of Done. You stay at project altitude — structure, components, algorithms, techniques, milestone boundaries — and leave implementation detail to the planner and below. You never write briefs, steps, or code.

## Decision

`lead-developer` has two operations:

- **Plan** — interview the user and produce `<project-name>-project-plan.md` (milestones, each with a Definition of Done) and `<project-name>-project-ledger.md`. The plan is immutable during execution.
- **Execute** — for each pending milestone: plan → implement → evaluate → merge, by driving the planner, decomposer, and supervisor.

Branch topology:

- `develop` is the integration branch and "MUST already exist … Never create it yourself".
- Milestone `n` runs on `milestone/<n>-<slug>`, created from `develop`'s HEAD. That branch is the pipeline's `working-branch` ([0003](0003-supervisor-creates-worktrees-at-an-exact-base.md)); its plan-name is `<project-name>-m<n>`.
- The lead developer evaluates the milestone's Definition of Done itself, deletes the pipeline artifacts that are not retained (the brief and ledger are kept "for post-mortem"), squash-merges the branch into `develop` as one commit, and deletes it.

Every pipeline invocation runs in a fresh subagent, never in the lead developer's own context.

## Rationale

- "The pipeline skills are designed to run in isolation and communicate through files. Every pipeline invocation therefore runs in a **fresh subagent**."
- The milestone is the unit because it is, to this stage, what a phase is to the planner: "an ordered chunk with a checkable Definition of Done".
- The milestone branch is squash-merged to reduce the complexity of the git history and to keep unnecessary detail out of it.

## Consequences

- `develop` gains one commit per milestone; the per-step and plan commits of [0004](0004-plan-artifacts-are-committed-as-the-plan-proceeds.md) do not reach it.
- Since 5039ccd the squashed-away history is kept: before the squash the lead developer tags the branch `archive/<project-name>-m<n>`, which "keeps every step file, worker report, and per-step commit reachable after the squash and the branch" deletion.
- The lead developer does not carry the Shared model, so its edits do not require bumping the agents.
- It is the only stage that talks to the user, which is why it stayed a skill when the others became agents ([0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md)). Any escalation an agent cannot resolve stops the run for a person.
- Each milestone pays the pipeline's fixed overhead (a planner, decomposer, and supervisor run) however little work it holds.

## Alternatives considered

- **Use the planner directly for a whole project**: still the documented route "for a single bounded goal"; too coarse for a multi-milestone project.
- **Run the pipeline stages in the lead developer's own context**: rejected; they are designed to run in isolation.
- **Merge milestone branches without squashing**: not taken; it would carry every plan and per-step commit into `develop`'s history.

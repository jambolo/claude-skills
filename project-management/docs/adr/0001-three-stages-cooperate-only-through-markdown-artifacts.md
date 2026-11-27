# 0001. Three stages (planner → decomposer → supervisor) cooperate only through Markdown artifacts keyed by `<plan-name>`

**Status:** Accepted
**Date:** 2026-07-04
**Commits:** e3ff846, 61ac934, fbc90c0, 5039ccd

## Context

e3ff846 ("Added project management skills") introduced a way to execute "a large, complex goal with a fleet of cheap-model worker subagents under expensive-model supervision". The work was split across three separately installed skills, each of which had to run without the others' conversation context. The planner's overview states the intent:

> Your job is to think hard about the goal *once*, at a high level, and write it down so the rest of the pipeline can run without re-deriving strategy.

Each skill carried the same "Shared model" section:

> These three skills cooperate through Markdown files, all keyed by one kebab-case `<plan-name>` … Each skill installs independently, so this section is repeated across all three — keep them in sync.

and the same rule for how the files are written:

> Every artifact above is read only by models — some weak and low-context — never by humans. Optimize for machine consumption: structured over prose … explicit over elegant (exact paths, exact commands, exact expected strings — no "see above" or other referential shorthand) … Completeness first, compactness second, polish never.

## Decision

The pipeline is three stages with fixed, non-overlapping jobs:

- **planner** — goal → `<plan-name>-brief.md`, a phased `<plan-name>-roadmap.md`, and a seeded `<plan-name>-ledger.md`.
- **decomposer** — one phase → atomic, parallelizable step files `<plan-name>-<id>.md`, each self-contained for a worker that "sees ONLY its step file".
- **supervisor** — one worker per step, verification, merge, and the failure → revision loop back through the decomposer.

Phases run in order; steps within a phase run in parallel wherever `depends_on` and disjoint `files_in_scope` allow. The stages share no state except the artifacts, which live in one directory (`artifacts-dir`, recorded in the ledger since 61ac934) and are written for models, not people. The contract the stages share — artifact table, roles, phase/step model, artifact style, and the protocols added later — is the "Shared model" section, duplicated verbatim in all three definitions.

## Rationale

- The goal is thought through once and written down "so the rest of the pipeline can run without re-deriving strategy" (planner).
- The Shared model is duplicated rather than referenced because "each skill installs independently".
- Artifacts are terse and literal because they are "read only by models — some weak and low-context — never by humans".

## Consequences

- A worker needs nothing but its step file, so the decomposer must project every fact a step needs out of the brief and roadmap into the step's `context`.
- A run is resumable and auditable from the files and git history alone; no stage depends on another's conversation.
- An edit to the Shared model is an edit to three files and three version bumps. Until 5039ccd this was a convention; `project-management/scripts/check-shared-model.sh` now exits 1 when the copies differ (the span from the section heading to the `<!-- shared-model: end -->` marker).
- The section grew with the pipeline: the integration model ([0003](0003-supervisor-creates-worktrees-at-an-exact-base.md)), the worker report and commit protocol ([0005](0005-a-step-ends-in-one-commit-with-a-fixed-report.md)), the amendment protocol ([0007](0007-brief-and-roadmap-stay-planner-owned-amendment-protocol.md)), the return protocol ([0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md)), and the formatter rule ([0011](0011-artifacts-are-excluded-from-formatter-gates.md)) all live in it.
- The artifacts are not pleasant for a person to read, by design.

## Alternatives considered

- **One skill doing planning, decomposition, and supervision in one context**: not taken; the design is built on stages that install and run independently.
- **A shared reference file for the common model**: not available to independently installed leaves, hence the duplication.

# CLAUDE.md — `project-management` family

Guidance for the lead-developer, planner, decomposer, and supervisor skills. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The pipeline

The **planner → decomposer → supervisor** pipeline executes a large goal with a fleet of cheap-model (Sonnet) worker subagents under expensive-model (Opus) supervision. `planner` turns a goal into a `<plan-name>-brief.md`, phased `<plan-name>-roadmap.md`, and seeded `<plan-name>-ledger.md`; `decomposer` breaks one phase into atomic, parallelizable step files `<plan-name>-<id>.md`; `supervisor` launches a worker per step (parallel steps isolated in git worktrees), verifies each against ground truth, merges passing work, and drives the failure → revision loop back through the decomposer.

The three skills install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three SKILL.md files and must be kept in sync** when edited.

## The lead-developer stage

`lead-developer` sits above the pipeline: its plan operation interviews the user and turns a project synopsis into a milestone-based `<project-name>-project-plan.md` plus a `<project-name>-project-ledger.md`; its execute operation executes each milestone on its own `milestone/<n>-<slug>` branch (from a pre-existing `develop`) by driving planner (fable/max), decomposer (fable/max), and supervisor (opus/high) — each invocation in a fresh subagent that calls the skill via the Skill tool, milestone `n` keyed by plan-name `<project-name>-m<n>` — then evaluates the milestone's Definition of Done itself, deletes non-retained artifacts (keeping brief + ledger for post-mortem), and squash-merges the branch into `develop`. It does not carry the pipeline's "Shared model" section and its edits do not require bumping the other three; any pipeline escalation a subagent cannot resolve stops the run for human intervention.

# CLAUDE.md — `project-management` family

Guidance for the planner → decomposer → supervisor skills. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The pipeline

The **planner → decomposer → supervisor** pipeline executes a large goal with a fleet of cheap-model (Sonnet) worker subagents under expensive-model (Opus) supervision. `planner` turns a goal into a `<plan-name>-brief.md`, phased `<plan-name>-roadmap.md`, and seeded `<plan-name>-ledger.md`; `decomposer` breaks one phase into atomic, parallelizable step files `<plan-name>-<id>.md`; `supervisor` launches a worker per step (parallel steps isolated in git worktrees), verifies each against ground truth, merges passing work, and drives the failure → revision loop back through the decomposer.

The three skills install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three SKILL.md files and must be kept in sync** when edited.

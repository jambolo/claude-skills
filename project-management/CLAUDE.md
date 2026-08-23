# CLAUDE.md — `project-management` family

Guidance for the `lead-developer` skill and the `planner`, `decomposer`, `supervisor`, and `worker` agents. See the repo root `CLAUDE.md` for skill/agent anatomy and repo-wide conventions.

## Skill vs. agent

Only `lead-developer` is a skill (`SKILL.md`): its plan operation interviews the user, which a subagent cannot do, and its execute operation runs inline at depth 0 so the chain below it fits the harness's three-level subagent limit. The four pipeline stages are **agent definitions** (`AGENT.md`, installed as `~/.claude/agents/<name>.md`): they never need the user mid-run, and the agent frontmatter gives what a skill cannot — pinned `model:`/`effort:` per stage, a `tools:` allowlist (the worker has no `Agent` tool), and `maxTurns:` on the worker.

| Leaf | Kind | model / effort | Spawns |
| --- | --- | --- | --- |
| `lead-developer` | skill | session's | planner, decomposer, supervisor |
| `planner` | agent | fable / max | nothing |
| `decomposer` | agent | fable / max | planner (amendment) |
| `supervisor` | agent | opus / high | worker, decomposer (revision), planner (amendment) |
| `worker` | agent | sonnet / low, `maxTurns: 80` | nothing (no `Agent` tool) |

Callers spawn a stage with `subagent_type: <name>` and pass **no** `model`, `effort`, or `isolation` option. Every agent ends with `RESULT: done | needs-human | failed`; a nested `needs-human` is forwarded verbatim up the chain until `lead-developer` (or the person who @-mentioned the agent) relays it to the user.

## The pipeline

The **planner → decomposer → supervisor** pipeline executes a large goal with a fleet of cheap-model (Sonnet) worker subagents under expensive-model supervision. `planner` turns a goal into a `<plan-name>-brief.md`, phased `<plan-name>-roadmap.md`, and seeded `<plan-name>-ledger.md`; `decomposer` breaks one phase into atomic, parallelizable step files `<plan-name>-<id>.md`; `supervisor` launches a `worker` per step (parallel steps isolated in git worktrees the supervisor creates itself), verifies each against ground truth, merges passing work, and drives the failure → revision loop back through the decomposer. `worker` carries the per-step contract (path discipline, base assertion, honest acceptance, report format, one-commit rule) in its own definition, so the supervisor hands it only a step packet.

The three pipeline agents install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three AGENT.md files and must be kept in sync** when edited (bump all three). `worker` does not carry it; its contract must stay consistent with the "Worker report & commit protocol" paragraph inside it.

## The lead-developer stage

`lead-developer` sits above the pipeline: its plan operation interviews the user and turns a project synopsis into a milestone-based `<project-name>-project-plan.md` plus a `<project-name>-project-ledger.md`; its execute operation executes each milestone on its own `milestone/<n>-<slug>` branch (from a pre-existing `develop`) by spawning `planner`, `decomposer`, and `supervisor` — each invocation a fresh agent, milestone `n` keyed by plan-name `<project-name>-m<n>` — then evaluates the milestone's Definition of Done itself, deletes non-retained artifacts (keeping brief + ledger for post-mortem), and squash-merges the branch into `develop`. It does not carry the pipeline's "Shared model" section and its edits do not require bumping the agents; any pipeline escalation an agent cannot resolve stops the run for human intervention.

## Editing an agent

- `description` is an auto-delegation trigger: keep the "invoke ONLY for pipeline work" exclusions, or the agent gets spawned on unrelated prompts.
- Changing `model`, `effort`, `tools`, or `maxTurns` is a minor bump; changing the packet/prompt contract or the `RESULT:` protocol is major.
- Agents can't ask the user — any new decision point must return `needs-human`, never assume.
- Installed definitions are read at session start; test in a fresh session after copying to `~/.claude/agents/`.

# CLAUDE.md — `project-management` family

Guidance for the `lead-developer` skill and the `planner`, `decomposer`, `supervisor`, and `worker` agents. See the repo root `CLAUDE.md` for skill/agent anatomy and repo-wide conventions.

## Skill vs. agent

Only `lead-developer` is a skill (`SKILL.md`): its plan operation interviews the user, which a subagent cannot do, and its execute operation runs inline at depth 0 so the chain below it fits the harness's three-level subagent limit. The four pipeline stages are **agent definitions** (`AGENT.md`, installed as `~/.claude/agents/<name>.md`): they never need the user mid-run, and the agent frontmatter gives what a skill cannot — pinned `model:`/`effort:` per stage, a `tools:` allowlist (the worker has no `Agent` tool), and `maxTurns:` on the worker.

| Leaf | Kind | Spawns |
| --- | --- | --- |
| `lead-developer` | skill | planner, decomposer, supervisor |
| `planner` | agent | nothing |
| `decomposer` | agent | planner (amendment) |
| `supervisor` | agent | worker, decomposer (revision), planner (amendment) |
| `worker` | agent | nothing (no `Agent` tool) |

Callers spawn a stage with `subagent_type: <name>` and `run_in_background: false` (omitted only when the Agent tool does not list it — an unlisted parameter fails the call), and pass **no** `model`, `effort`, or `isolation` option. Every agent ends with `RESULT: done | needs-human | failed`; a nested `needs-human` is forwarded verbatim up the chain until `lead-developer` (or the person who @-mentioned the agent) relays it to the user.

## The pipeline

The supervisor creates the git worktrees for parallel steps itself. `worker` carries the per-step contract (path discipline, base assertion, honest acceptance, report format, one-commit rule) in its own definition, so the supervisor hands it only a step packet.

The three pipeline agents install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three AGENT.md files and must be kept in sync** when edited (bump all three). `worker` does not carry it; its contract must stay consistent with the "Worker report & commit protocol" paragraph inside it.

## The lead-developer stage

`lead-developer` does not carry the pipeline's "Shared model" section and its edits do not require bumping the agents; any pipeline escalation an agent cannot resolve stops the run for human intervention.

## Editing an agent

- `description` is an auto-delegation trigger: keep the "invoke ONLY for pipeline work" exclusions, or the agent gets spawned on unrelated prompts.
- Changing `model`, `effort`, `tools`, or `maxTurns` is a minor bump; changing the packet/prompt contract or the `RESULT:` protocol is major.
- Agents can't ask the user — any new decision point must return `needs-human`, never assume.
- Installed definitions are read at session start; test in a fresh session after copying to `~/.claude/agents/`.

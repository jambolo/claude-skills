# 0010. The pipeline stages are agent definitions with pinned model, effort, and tools; only `lead-developer` is a skill

**Status:** Accepted
**Date:** 2026-08-23
**Commits:** 5cde06f, 68ecbaa, 5039ccd

## Context

Through a3a7d2f the planner, decomposer, and supervisor were skills. A person, or a `general-purpose` subagent started by `lead-developer`, loaded one with the Skill tool, and the caller chose the model and effort on each launch (the lead-developer skill carried a table of them). The worker was not a leaf at all: its contract was a paragraph the supervisor pasted into every launch prompt.

5cde06f ("Converted planner and supervisor skills to agents. Created a worker agent. Pinned model/effort in the agent front matter.") changed the kind of all three stages and added a fourth leaf. The family `CLAUDE.md` gained a "Skill vs. agent" section:

> Only `lead-developer` is a skill (`SKILL.md`): its plan operation interviews the user, which a subagent cannot do, and its execute operation runs inline at depth 0 so the chain below it fits the harness's three-level subagent limit. The four pipeline stages are **agent definitions** … they never need the user mid-run, and the agent frontmatter gives what a skill cannot — pinned `model:`/`effort:` per stage, a `tools:` allowlist (the worker has no `Agent` tool), and `maxTurns:` on the worker.

## Decision

- `planner`, `decomposer`, `supervisor`, and `worker` are `AGENT.md` leaves installed as `~/.claude/agents/<name>.md`. `lead-developer` remains a skill.
- Each definition pins `model:`, `effort:`, and `tools:`. Callers spawn with `subagent_type: <name>` and pass **no** `model`, `effort`, or `isolation` option.
- The worker's contract (path discipline, base assertion, honest acceptance, report format, one-commit rule) lives in its own definition; the supervisor hands it only a packet.
- No agent can reach the user, so every run ends with exactly one `RESULT:` line — `done`, `needs-human`, or `failed` (`needs-amendment` was added for the decomposer in 5039ccd, see [0007](0007-brief-and-roadmap-stay-planner-owned-amendment-protocol.md)). A nested `needs-human` "is forwarded verbatim up the chain until `lead-developer` (or the person who @-mentioned the agent) relays it to the user". "Agents can't ask the user — any new decision point must return `needs-human`, never assume."
- Model ids in frontmatter are aliases (`fable`, `opus`, `sonnet`), not versioned ids (68ecbaa: `claude-fable-5` → `fable`).

## Rationale

The quoted `CLAUDE.md` section is the stated reasoning: the stages "never need the user mid-run", and agent frontmatter "gives what a skill cannot". `lead-developer` stays a skill because it interviews the user and because running inline at depth 0 keeps the chain within the harness's nesting limit.

## Consequences

- `skill-version-check` had to learn a second kind in the same commit (see `skill-management/docs/adr/0007`).
- An agent's `description` is an auto-delegation trigger, so each carries "invoke ONLY for pipeline work" exclusions.
- Installed definitions are read at session start; a change is tested in a fresh session.
- The pins are text in several places — each frontmatter, the three Shared model copies, the lead-developer model table, the README — and must be changed together.
- The design depends on harness defaults (nesting depth, concurrency) that the family `CLAUDE.md` lists as facts to re-check after an upgrade.
- 5039ccd used two more frontmatter keys: `omitClaudeMd: true` on the workers "so they see their step file and nothing else — not even the project's CLAUDE.md", and removal of the `Agent` tool from the decomposer, leaving the supervisor as the only stage that spawns.
- A change of `model`, `effort`, `tools`, `maxTurns`, or `omitClaudeMd` is a minor bump; a change to the packet contract, the `RESULT:` protocol, or an artifact format is major.

## Alternatives considered

- **Stages as skills loaded by a general-purpose subagent, with the caller passing model and effort** (0719e9c through a3a7d2f): the pins lived in callers' prose, there was no tool allowlist or turn cap, and the worker contract was re-sent with every launch.
- **Make `lead-developer` an agent too**: not possible; "its plan operation interviews the user, which a subagent cannot do".
- **Versioned model ids in frontmatter** (5cde06f): replaced by aliases in 68ecbaa.

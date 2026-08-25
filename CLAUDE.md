# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Authoring source for a collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills). There is no application, build, or test runner — the deliverable is the skill content itself. A skill is "run" by installing it (copy its folder to `~/.claude/skills/<name>/`) or packaging it, then invoking it from a Claude session.

## Repository layout

Skills and agents are grouped by family into category folders at the repo root. Each category folder holds one or more **leaf folders**, each of which is either a **skill** (holds `SKILL.md`) or an **agent** (holds `AGENT.md` — a Claude Code subagent definition). A leaf never holds both.

The category folders are organizational only — the unit of installation and discovery is the **leaf folder**. A skill leaf is copied whole to `~/.claude/skills/<name>/`; an agent leaf's `AGENT.md` is copied to the single file `~/.claude/agents/<name>.md`.

## Skill and agent anatomy

The `description` frontmatter is the dispatch trigger — it is the only thing Claude sees when deciding whether to invoke the skill or delegate to the agent. It must enumerate concrete trigger phrases and cross-reference siblings to disambiguate where their scopes are adjacent. When editing either, treat `description` as load-bearing, not as a summary. An agent's description is also an **auto-delegation** trigger, so it must additionally say what the agent is *not* for — an over-broad agent description gets the agent spawned on unrelated prompts.

Leaf folder name must equal frontmatter `name` (kebab-case). Installation and discovery assume this — the enclosing category folder is not part of the name.

Agent frontmatter additionally pins `model:` and `effort:` (so a caller never passes them), restricts `tools:` (a worker has no `Agent` tool), and may set `maxTurns:`. Agents run as isolated subagents: they cannot talk to the user, so every agent body ends with a `RESULT: done | needs-human | failed` return protocol that the caller parses. Agent definitions are read at session start — a changed agent needs a new session.

## Versioning

Every `SKILL.md` and `AGENT.md` carries a semver `version:` line directly under `name:`, and `manifest.json` at the repo root mirrors it for every entry (including `skill-version-check` itself); every entry carries `"kind"`, either `"skill"` or `"agent"` — there is no default kind, and the entries live in the manifest's `entries` array. **The two must always agree** — a mismatch is "manifest drift" and is treated as an error by the `skill-version-check` skill, which compares the manifest against the versions installed under `~/.claude/skills/` and `~/.claude/agents/`.

After changing a skill's or agent's content, bump its `version:` (patch = wording, minor = new capability or a changed agent `model`/`effort`/`tools`, major = changed operations/inputs/artifact formats or a change of kind) **and** update its manifest entry in the same commit. Editing the `project-management` shared "Shared model" section means bumping all three of `planner`, `decomposer`, `supervisor`.

## Four skill families

Each family has its own `CLAUDE.md` with the detail; it loads when you work under that folder.

- **`advent-of-code/`** — the language-agnostic AoC skill. See `advent-of-code/CLAUDE.md`.
- **`new-project/`** — the per-language scaffolders, which also bootstrap `advent-of-code` scaffolds. See `new-project/CLAUDE.md`: its **"Scaffolder conventions"** section is the shared contract, and `advent-of-code`'s inline scaffold fallback follows it too.
- **`project-management/`** — the `lead-developer` skill over the planner → decomposer → supervisor pipeline, whose stages (plus the supervisor's `worker`) are **agents**, not skills. See `project-management/CLAUDE.md`. When editing any of the three pipeline agents, the **"Shared model" section is duplicated verbatim across all three AGENT.md files and must be kept in sync**.
- **`skill-management/`** — version bookkeeping: `skill-version-check` (this repo's skills/agents) and `script-version-check` (external bash-script repos → `~/bin`). See `skill-management/CLAUDE.md`.

## Validating a change

- End-to-end: copy the skill folder to `~/.claude/skills/<name>/` (or the agent's `AGENT.md` to `~/.claude/agents/<name>.md`, then start a new session), invoke it in an empty scratch directory, and inspect the resulting git log + tree.
- Frontmatter sanity: `name` matches the folder; `version` is bumped and matches `manifest.json`; `description` lists trigger phrases (and, for an agent, exclusions).
- Version/manifest state: `pwsh skill-management/skill-version-check/scripts/Compare-SkillVersions.ps1 -RepoRoot .` (or `bash skill-management/skill-version-check/scripts/compare-skill-versions.sh --repo-root .`) — the "Manifest drift" section must be empty.

## Notes

- Scaffolds depend on external tooling on PATH (`git`, `npm`/`npx`, `pnpm`, `cargo`, `cmake`, `julia` + `PkgTemplates`) depending on the target language.

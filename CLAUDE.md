# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Authoring source for a collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills). There is no application, build, or test runner — the deliverable is the skill content itself. A skill is "run" by installing it (copy its folder to `~/.claude/skills/<name>/`) or packaging it, then invoking it from a Claude session.

## Repository layout

Skills are grouped by family into category folders at the repo root. Each category folder holds one or more **leaf skill folders**.

The category folders are organizational only — the unit of installation and discovery is the **leaf skill folder**, which is what gets copied to `~/.claude/skills/<name>/`.

## Skill anatomy

The `description` frontmatter is the dispatch trigger — it is the only thing Claude sees when deciding whether to invoke the skill. It must enumerate concrete trigger phrases and cross-reference sibling skills to disambiguate where their scopes are adjacent. When editing a skill, treat `description` as load-bearing, not as a summary.

Leaf folder name must equal frontmatter `name` (kebab-case). Installation and discovery assume this — the enclosing category folder is not part of the skill name.

## Three skill families

Each family has its own `CLAUDE.md` with the detail; it loads when you work under that folder.

- **`advent-of-code/`** — the language-agnostic AoC skill. See `advent-of-code/CLAUDE.md`.
- **`new-project/`** — the per-language scaffolders, which also bootstrap `advent-of-code` scaffolds. See `new-project/CLAUDE.md`: its **"Scaffolder conventions"** section is the shared contract, and `advent-of-code`'s inline scaffold fallback follows it too.
- **`project-management/`** — the planner → decomposer → supervisor pipeline. See `project-management/CLAUDE.md`. When editing any of those three skills, the **"Shared model" section is duplicated verbatim across all three SKILL.md files and must be kept in sync**.

## Validating a change

- End-to-end: copy the skill folder to `~/.claude/skills/<name>/`, invoke it in an empty scratch directory, and inspect the resulting git log + tree.
- Frontmatter sanity: `name` matches the folder; `description` lists trigger phrases.

## Notes

- Scaffolds depend on external tooling on PATH (`git`, `npm`/`npx`, `pnpm`, `cargo`, `cmake`, `julia` + `PkgTemplates`) depending on the target language.

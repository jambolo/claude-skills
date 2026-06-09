# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Authoring source for a collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills). There is no application, build, or test runner — the deliverable is the skill content itself. A skill is "run" by installing it (copy its folder to `~/.claude/skills/<name>/`) or packaging it, then invoking it from a Claude session.

## Skill anatomy

Each skill is one top-level folder containing:

- `SKILL.md` — required. YAML frontmatter (`name`, `description`) followed by the instruction body Claude executes.
- `templates/` — optional. Files instantiated by token substitution during scaffolding.
- `reference/` — optional. Static assets (e.g. `mit-license.txt`).

The `description` frontmatter is the dispatch trigger — it is the only thing Claude sees when deciding whether to invoke the skill. It must enumerate concrete trigger phrases and cross-reference sibling skills to disambiguate where their scopes are adjacent. When editing a skill, treat `description` as load-bearing, not as a summary.

Folder name must equal frontmatter `name` (kebab-case). Installation and discovery assume this.

## Two skill families

- **`advent-of-code`** — language-agnostic, multi-operation (init / scaffold / stub / run). Instruction-only (no templates); derives everything per-project from CLAUDE.md and existing files rather than hardcoding a language.
- **`new-*-project`** — per-language scaffolders (cpp, julia, rust, typescript).

**`new-rust-project` is the reference implementation** — the most complete scaffolder (full CI/CD workflows, templates, reference assets). The other `new-*` skills are first-pass and will be expanded to roughly the same level. When extending one of them, mirror `new-rust-project`'s structure and depth.

## Scaffolder conventions (shared across `new-*`)

All scaffolders converge on the same shape — preserve it when adding or editing one:

- Git-first: `git init`, then **one commit per setup step** ("New repo" empty commit, then `.gitignore`, MIT license, README, build config…). The seeded-commit history is intentional output, not incidental.
- Always produce: MIT license (`Copyright (c) <year> John Bolton`), language-appropriate `.gitignore`, README headed by the folder/project name.
- Templates use placeholder tokens (`PROJECT_NAME`, `<name>`). `.in` suffix = CMake `configure_file` input.

## Validating a change

- End-to-end: copy the skill folder to `~/.claude/skills/<name>/`, invoke it in an empty scratch directory, and inspect the resulting git log + tree.
- Frontmatter sanity: `name` matches the folder; `description` lists trigger phrases.

## Notes

- `.claude/` and `.vscode/` are gitignored — local settings, not part of any skill.
- Scaffolds depend on external tooling on PATH (`git`, `npm`/`npx`, `pnpm`, `cargo`, `cmake`, `julia` + `PkgTemplates`) depending on the target language.

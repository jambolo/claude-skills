# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Authoring source for a collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills). There is no application, build, or test runner — the deliverable is the skill content itself. A skill is "run" by installing it (copy its folder to `~/.claude/skills/<name>/`) or packaging it, then invoking it from a Claude session.

## Repository layout

Skills are grouped by family into category folders at the repo root. Each category folder holds one or more **leaf skill folders**:

```text
advent-of-code/       # family
  advent-of-code/     # leaf skill
new-project/          # family
  new-cpp-project/    # leaf skill
  new-haskell-project/
  new-julia-project/
  new-rust-project/
  new-tauri-project/
  new-typescript-project/
project-management/   # family
  planner/            # leaf skills (planner → decomposer → supervisor pipeline)
  decomposer/
  supervisor/
```

The category folders are organizational only — the unit of installation and discovery is the **leaf skill folder**, which is what gets copied to `~/.claude/skills/<name>/`.

## Skill anatomy

Each leaf skill folder contains:

- `SKILL.md` — required. YAML frontmatter (`name`, `description`) followed by the instruction body Claude executes.
- `templates/` — optional. Files instantiated by token substitution during scaffolding.
- `reference/` — optional. Static assets (e.g. `mit-license.txt`).

The `description` frontmatter is the dispatch trigger — it is the only thing Claude sees when deciding whether to invoke the skill. It must enumerate concrete trigger phrases and cross-reference sibling skills to disambiguate where their scopes are adjacent. When editing a skill, treat `description` as load-bearing, not as a summary.

Leaf folder name must equal frontmatter `name` (kebab-case). Installation and discovery assume this — the enclosing category folder is not part of the skill name.

## Three skill families

- **`advent-of-code`** — language-agnostic, multi-operation (init / scaffold / stub / run). Instruction-only (no templates). For existing projects it derives everything from the project's CLAUDE.md and files. Its scaffold operation is layered: repo bootstrap is **delegated to the matching `new-*-project` skill** via the Skill tool (inline fallback following the shared scaffolder conventions for languages without one), then the AoC-specific layout is **researched from community practice** (well-starred repos, templates, dominant tooling) rather than hardcoded — the chosen structure and its sources are recorded in the generated project's CLAUDE.md.
- **`new-*-project`** — per-language scaffolders (cpp, haskell, julia, rust, typescript), plus the multi-stack `new-tauri-project` (Rust compute-core + TypeScript frontend + Tauri shell). Also serve as the bootstrap layer for `advent-of-code` scaffolds, so behavior changes here propagate there.
- **`project-management`** — the **planner → decomposer → supervisor** pipeline for executing a large goal with a fleet of cheap-model (Sonnet) worker subagents under expensive-model (Opus) supervision. `planner` turns a goal into a `<plan-name>-brief.md`, phased `<plan-name>-roadmap.md`, and seeded `<plan-name>-ledger.md`; `decomposer` breaks one phase into atomic, parallelizable step files `<plan-name>-<id>.md`; `supervisor` launches a worker per step (parallel steps isolated in git worktrees), verifies each against ground truth, merges passing work, and drives the failure → revision loop back through the decomposer. The three skills install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three SKILL.md files and must be kept in sync** when edited.

## Scaffolder conventions (shared across `new-*`)

All scaffolders converge on the same shape — preserve it when adding or editing one:

- Git-first: `git init`, then **one commit per setup step** ("New repo" empty commit, then `.gitignore`, MIT license, README, build config…). The seeded-commit history is intentional output, not incidental.
- Generator preference order: **language-native tooling first** (`cargo`, `cabal init`, `PkgTemplates`, `tsc --init`), **npx generators second** (`npx gitignore <lang>`, `npx license MIT` — even in non-Node projects), **bundled templates / hand-written content last**. Reading author info from git config is fine.
- **pnpm is the preferred package manager for Node-based projects** — `new-typescript-project` is pnpm-only by design (not an omission), and any future Node-based scaffolder should default to pnpm too (`pnpm add`, `pnpm dlx` instead of `npx`). Plain `npx` remains fine for one-off generators in non-Node projects.
- Always produce: MIT license (`Copyright (c) <year> <git config user.name>`), language-appropriate `.gitignore` that **includes `.vscode/`**, README headed by the folder/project name.
- Idempotent / partial-setup aware: each skill has a "Partially set-up projects" section — existing artifacts are kept (`.gitignore` is merged by appending missing entries), generation is skipped when the language manifest already exists, and a step is committed only if it changed something.
- act validation is optional: skipped (and reported as skipped) when `act` is not on PATH or Docker isn't running.
- Templates use placeholder tokens (`PROJECT_NAME`, `<name>`). `.in` suffix = CMake `configure_file` input.

## Validating a change

- End-to-end: copy the skill folder to `~/.claude/skills/<name>/`, invoke it in an empty scratch directory, and inspect the resulting git log + tree.
- Frontmatter sanity: `name` matches the folder; `description` lists trigger phrases.

## Notes

- `.claude/` and `.vscode/` are gitignored — local settings, not part of any skill.
- Scaffolds depend on external tooling on PATH (`git`, `npm`/`npx`, `pnpm`, `cargo`, `cmake`, `julia` + `PkgTemplates`) depending on the target language.

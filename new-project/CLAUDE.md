# CLAUDE.md — `new-project` family

Guidance for the `new-*-project` scaffolders. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The skills

Per-language scaffolders (cpp, haskell, julia, rust, typescript). They also serve as the bootstrap layer for `advent-of-code` scaffolds, so behavior changes here propagate there.

## Scaffolder conventions (shared across `new-*`)

All scaffolders converge on the same shape — preserve it when adding or editing one:

- Git-first: `git init`, then **one commit per setup step** ("New repo" empty commit, then `.gitignore`, MIT license, README, build config…). The seeded-commit history is intentional output, not incidental.
- Generator preference order: **language-native tooling first** (`cargo`, `cabal init`, `PkgTemplates`, `tsc --init`), **npx generators second** (`npx gitignore <lang>`, `npx license MIT` — even in non-Node projects), **bundled templates / hand-written content last**. Reading author info from git config is fine.
- **pnpm is the preferred package manager for Node-based projects** — `new-typescript-project` is pnpm-only by design (not an omission), and any future Node-based scaffolder should default to pnpm too (`pnpm add`, `pnpm dlx` instead of `npx`). Plain `npx` remains fine for one-off generators in non-Node projects.
- Always produce: MIT license (`Copyright (c) <year> <git config user.name>`), language-appropriate `.gitignore` that **includes `.vscode/`**, README headed by the folder/project name.
- Idempotent / partial-setup aware: each skill has a "Partially set-up projects" section — existing artifacts are kept (`.gitignore` is merged by appending missing entries), generation is skipped when the language manifest already exists, and a step is committed only if it changed something.
- act validation is optional: skipped (and reported as skipped) when `act` is not on PATH or Docker isn't running.
- Templates use placeholder tokens (`PROJECT_NAME`, `<name>`). `.in` suffix = CMake `configure_file` input.

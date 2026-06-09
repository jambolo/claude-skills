# Claude Skills

A collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) for scaffolding new projects and managing Advent of Code solutions.

## advent-of-code

Manages Advent of Code projects in any language. Four operations:

- **init** — generate or update CLAUDE.md with project-specific process documentation
- **scaffold** — create the full project directory structure and starter files for a new year or day
- **stub** — add a stub for a new day to an existing project
- **run** — execute a day's solution and verify output against the answers in README.md

## new-cpp-project

Scaffolds a C++ CMake project in a new directory — executable or library — with git repo, seeded commits, MIT license, Visual-Studio-aware .gitignore, README, and CMakeLists.txt rendered from bundled templates.

Library variant includes:

- Doxygen configuration
- Package config file
- GTest test directory (`test/`)
- `include/<name>/` layout

## new-julia-project

Scaffolds a Julia package via `PkgTemplates` — generates Project.toml (v0.1.0), git repo with Julia-tuned .gitignore rules, default `src/` and `test/` directories, and a custom GitHub Actions CI workflow that builds, tests, lints, and checks formatting.

## new-rust-project

Scaffolds a Rust project via `cargo new`, then layers on a comprehensive .gitignore, MIT license, README, GitHub Actions CI/CD workflows, and per-step git commits.

## new-typescript-project

Scaffolds a strict TypeScript project with npm or pnpm (user's choice) in the current directory — git repo with seeded commits, MIT license, .gitignore, README, strict tsconfig, ESLint, Prettier, Vitest, and a GitHub Actions CI workflow that compiles, tests, lints, and checks formatting.

## Repository layout

Each skill lives in its own folder containing a `SKILL.md` (the skill definition with YAML frontmatter) plus optional `templates/` and `reference/` assets.

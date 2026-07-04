# Claude Skills

A collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) for scaffolding new projects, running a supervised multi-agent project-management pipeline, and managing Advent of Code solutions. Skills are grouped by family into category folders (`advent-of-code/`, `new-project/`, `project-management/`), each holding one or more leaf skill folders.

## advent-of-code

Manages Advent of Code projects in any language. Four operations:

- **init** — generate or update CLAUDE.md with project-specific process documentation
- **scaffold** — create the full project directory structure and starter files for a new year or day
- **stub** — add a stub for a new day to an existing project
- **run** — execute a day's solution and verify output against the answers in README.md

## project-management

A three-skill pipeline for executing a large, complex goal with a fleet of cheap-model (Sonnet) worker subagents under expensive-model (Opus) supervision. The stages cooperate through Markdown artifacts keyed by a shared `<plan-name>`, and each installs independently.

- **planner** — turns a high-level goal into three artifacts: a `<plan-name>-brief.md` (goal, context, constraints, Definition of Done), a phased `<plan-name>-roadmap.md` (ordered phases with per-phase exit criteria), and a seeded `<plan-name>-ledger.md` (live execution state). High-level planning only.
- **decomposer** — breaks one phase into atomic, parallelizable **step** files (`<plan-name>-<id>.md`), each self-contained for a low-context worker: projects the needed slice of the brief/roadmap into the step's `context`, wires `depends_on`, keeps parallel steps' file scopes disjoint, and gives each a concrete `acceptance` command with an exact expected result.
- **supervisor** — launches one worker per step (parallel steps isolated in their own git worktrees), then verifies each result against ground truth by re-running every `acceptance` command and confirming only the declared files changed. Merges passing work, records commit SHAs in the ledger, and drives the failure → revision loop by re-invoking the decomposer. Never trusts a worker's self-report.

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

Skills are grouped by family into category folders at the repo root — `advent-of-code/`, `new-project/`, and `project-management/`. Each category folder holds one or more leaf skill folders, and each leaf folder contains a `SKILL.md` (the skill definition with YAML frontmatter) plus optional `templates/` and `reference/` assets. The leaf folder is the unit of installation: copy it to `~/.claude/skills/<name>/`, where `<name>` matches its `SKILL.md` frontmatter.

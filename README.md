# Claude Skills

A collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) for scaffolding new projects, running a supervised multi-agent project-management pipeline, managing Advent of Code solutions, and keeping the installed copies of these skills up to date. Skills are grouped by family into category folders (`advent-of-code/`, `new-project/`, `project-management/`, `skill-management/`), each holding one or more leaf skill folders.

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

## new-project

Scaffolds new projects for specific languages. Whether done explicitly or via the language's platform tooling, every skill produces:

1. A project folder named after the project — created if it doesn't already exist, used as-is otherwise.
2. A git repo whose seeded commit history reflects the setup steps, one commit per step.
3. A language-tuned `.gitignore`, an MIT license, and a README seeded with the project name.
4. The language's native project manifest / build configuration (`CMakeLists.txt`, `<name>.cabal`, `Project.toml`, `Cargo.toml`, `package.json` + `tsconfig.json`, or for Tauri a cargo workspace plus `package.json` + `tauri.conf.json`).
5. A skeleton source layout ready to build.
6. A GitHub Actions CI workflow (build + test on every push; lint + format checks gated to pull requests).

### new-cpp-project

Scaffolds a C++ CMake project as an **executable** (default) or **library**, rendering `CMakeLists.txt` from a bundled template with the project name and description substituted. The `.gitignore` is Visual-Studio-aware. Placeholder sources (`main.cpp`, or the library's header/source pair) are created but intentionally left uncommitted.

The library variant additionally produces a Doxygen config, a CMake package config (`find_package` support with install/export wiring), and a GTest `test/` directory whose GoogleTest dependency is fetched via `FetchContent` when tests are enabled (`-D<name>_BUILD_TESTS=ON`).

CI builds and runs `ctest` on an `ubuntu-latest` + `windows-latest` matrix; pull requests also get a `clang-format` check and a `clang-tidy` lint against the CMake compile database. Library scaffolds additionally get a **docs** job (master only — Doxygen HTML to GitHub Pages), a **coverage** job (develop only — gcovr results to Codecov), and a **CD workflow** that watches the `project()` version in `CMakeLists.txt` on master, tags `v<version>`, and merges master back into develop.

### new-haskell-project

Scaffolds a Haskell package by driving `cabal init` non-interactively — cabal's own generator produces the `.cabal` manifest, starter sources, test suite, `CHANGELOG.md`, and the MIT `LICENSE` (author and year filled from git config), so the skill bundles no source templates at all. Kinds: **library + executable** (default — the testable-application layout with a thin `app/Main.hs` over a `src/` library), **executable**, or **library**.

CI builds and runs `cabal test` on an `ubuntu-latest` + `windows-latest` matrix, pinning GHC to the scaffold-time compiler (cabal pins `base` to it) and caching the cabal store per build plan; pull requests also get an Ormolu format check and an HLint lint. The workflow is verified locally with [act](https://github.com/nektos/act).

### new-julia-project

Scaffolds a Julia package by driving `PkgTemplates` non-interactively — it generates the `Project.toml` (v0.1.0), git repo, Julia-tuned `.gitignore`, and `src/` + `test/` skeleton, with the stock README, license, and workflow plugins disabled so the skill's own versions are used instead. CI builds the package and runs `Pkg.test`; pull requests also get a JuliaFormatter format check and a JET static lint. The workflow is verified locally with [act](https://github.com/nektos/act).

### new-rust-project

Scaffolds a Rust crate via `cargo new` (or `cargo init` into an existing folder). CI builds and tests on an `ubuntu-latest` + `windows-latest` matrix; pull requests also get `cargo fmt --check` and `cargo clippy -D warnings`; a **docs** job (master only) builds `cargo doc` and deploys to GitHub Pages, and a **coverage** job (develop only) uploads `cargo llvm-cov` results to Codecov. A separate **CD workflow** watches `Cargo.toml` on master and, after a build/test gate, tags `v<version>` and merges master back into develop. The CI workflow is verified locally with [act](https://github.com/nektos/act).

### new-typescript-project

Scaffolds a strict TypeScript project with **pnpm**. Beyond the common baseline it installs and configures the toolchain locally: a strict `tsconfig.json` generated by `tsc --init` (then patched), ESLint (flat config with typescript-eslint), Prettier, Vitest with V8 coverage, and TypeDoc, wired up as `build` / `lint` / `format` / `format:check` / `test` / `coverage` / `docs` scripts in `package.json`, plus a sample `src/index.ts` with a passing test. CI builds and tests on an `ubuntu-latest` + `windows-latest` matrix; pull requests also get the lint and format checks; a **docs** job (master only) deploys TypeDoc to GitHub Pages, and a **coverage** job (develop only) uploads lcov to Codecov. A separate **CD workflow** watches `package.json` on master, tags `v<version>`, and merges master back into develop. The CI workflow is verified locally with [act](https://github.com/nektos/act).

### new-tauri-project

Scaffolds a [Tauri](https://tauri.app/) desktop application as three strictly separated layers: a cargo workspace holding a UI-agnostic Rust compute-core crate (`src-core`, all logic and tests, no Tauri dependency) and a thin Tauri shell crate (`src-tauri`, window + commands + serde protocol), plus a strict TypeScript frontend (`src`) built with Vite, tested with Vitest, and managed with **pnpm** — where `api.ts` is the only module that touches `@tauri-apps/api`. A sample "greet" flow is wired through all three layers so a new app can grow by imitation. Tooling preference matches the sibling skills (`pnpm`, `cargo`, `pnpm dlx gitignore` / `license`), falling back to bundled templates; `tsconfig.json` is deliberately template-sourced because a Vite app needs `moduleResolution: bundler` + `noEmit`.

CI builds the frontend first (Tauri embeds `dist/` at compile time), then builds and tests both stacks on an `ubuntu-latest` + `windows-latest` + `macos-latest` matrix — one leg per platform the app ships on, since Tauri does not cross-compile. Pull requests also get `cargo fmt --check`, `cargo clippy -D warnings`, ESLint, and Prettier; a **coverage** job (develop only) uploads `cargo llvm-cov` and Vitest lcov to Codecov. No docs job — it's an application, not a library. A separate **CD workflow** watches `package.json` on master, tags `v<version>` after a full both-stack build/test gate, and merges master back into develop.

## skill-management

Repo self-maintenance.

### skill-version-check

Keeps the skills installed under `~/.claude/skills/` in step with this repo. Every `SKILL.md` carries a semver `version:` in its frontmatter, and `skills-manifest.json` at the repo root records the current version of every skill; the two must always agree. The skill first pulls the latest `jambolo/claude-skills` from GitHub (fast-forward only — it never rebases, stashes, or discards local work), then compares the manifest against the installed copies and reports each skill as `OK`, `OUTDATED`, `AHEAD`, `MISSING`, `UNVERSIONED`, or `DIFFERENT`, plus any manifest drift and any installed skills the repo doesn't own. On request it mirrors repo → install root for the skills you confirm (`robocopy /MIR` on Windows, `rsync -a --delete` elsewhere), regenerates the manifest from frontmatter, or bumps a skill's version after an edit.

The comparison logic ships as two equivalent scripts — `scripts/Compare-SkillVersions.ps1` for PowerShell and `scripts/compare-skill-versions.sh` for bash (no `jq` required) — both with a JSON output mode:

```powershell
& ".\skill-management\skill-version-check\scripts\Compare-SkillVersions.ps1" -RepoRoot . [-Json]
```

```bash
bash skill-management/skill-version-check/scripts/compare-skill-versions.sh --repo-root . [--json]
```

## Repository layout

Skills are grouped by family into category folders at the repo root — `advent-of-code/`, `new-project/`, `project-management/`, and `skill-management/`. Each category folder holds one or more leaf skill folders, and each leaf folder contains a `SKILL.md` (the skill definition with YAML frontmatter, including a semver `version:`) plus optional `templates/`, `reference/`, and `scripts/` assets. The leaf folder is the unit of installation: copy it to `~/.claude/skills/<name>/`, where `<name>` matches its `SKILL.md` frontmatter — or let `skill-version-check` do it.

`skills-manifest.json` at the repo root lists every skill with its current version and path; it is kept in lockstep with the `SKILL.md` frontmatter and is what `skill-version-check` compares installed copies against.

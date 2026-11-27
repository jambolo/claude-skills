# Architectural Decision Records — `new-project` family

Decisions that shape the `new-*-project` scaffolders, numbered in the order they were made (commit date of the commit that introduced the decision; e5badcf is dated by its author date, 2026-06-10, since it was written before ba697a6 and landed later). The family is six instruction-plus-template skills (`new-cpp-project`, `new-haskell-project`, `new-julia-project`, `new-rust-project`, `new-tauri-project`, `new-typescript-project`) with no agents or scripts; the shared contract lives in `new-project/CLAUDE.md`.

| # | Title | Status | Date | Superseded by |
| --- | --- | --- | --- | --- |
| [0001](0001-shared-ci-cd-workflow-topology.md) | CI/CD ships as bundled workflow templates with one shared job topology | Accepted | 2026-06-09 | — |
| [0002](0002-template-pins-are-a-baseline-refreshed-at-scaffold-time.md) | Template version pins are a baseline the skill refreshes at scaffold time with `git ls-remote` | Accepted | 2026-06-09 | — |
| [0003](0003-pnpm-only-for-node-scaffolds.md) | Node-based scaffolds are pnpm-only and create their own directory | Accepted | 2026-06-10 | — |
| [0004](0004-generator-preference-order.md) | Generator preference order: native tooling, then npx generators, then bundled templates | Accepted | 2026-07-09 | — |
| [0005](0005-idempotent-partial-setup-mode.md) | Every scaffolder is idempotent and finishes a partially set-up project | Accepted | 2026-07-09 | — |
| [0006](0006-act-validation-is-optional-and-reported.md) | Local workflow validation with act is optional, scoped to runnable jobs, and reported | Accepted | 2026-07-09 | — |
| [0007](0007-publishing-jobs-follow-scaffold-kind.md) | Publishing jobs (docs, coverage, CD release) follow the scaffold's kind | Accepted | 2026-07-09 | — |
| [0008](0008-scaffold-commit-messages-are-exact-no-attribution-trailers.md) | Scaffold commit messages are exactly the ones the skill gives: no attribution trailers | Accepted | 2026-10-16 | — |
| [0009](0009-cpp-builds-are-driven-by-a-committed-cmakepresets-json.md) | C++ scaffolds commit a `CMakePresets.json`, and CI runs CMake only through it | Accepted | 2026-11-24 | — |
| [0010](0010-cpp-templates-target-current-cmake.md) | C++ templates target current CMake: a 3.28 floor for executables, 4.5 for libraries, built-in features over hand-rolled ones | Accepted | 2026-11-24 | — |
| [0011](0011-cpp-scaffolds-ship-a-clang-format.md) | C++ scaffolds ship a `.clang-format` so the CI format check has a stated style | Accepted | 2026-11-26 | — |

## Reversed designs

No ADR is superseded, but several earlier designs were reversed by later commits and are recorded under "Alternatives considered" in the ADR that replaced them:

| Initial design | Commit | Replaced by |
| --- | --- | --- |
| Per-package-manager CI templates (`ci-npm.yml`, `ci-pnpm.yml`); no CI for C++ | 646403b | [0001](0001-shared-ci-cd-workflow-topology.md) (e5badcf, ba697a6) |
| Literal `node-version: 24` bumped by hand | e5badcf | [0002](0002-template-pins-are-a-baseline-refreshed-at-scaffold-time.md) (167878f) |
| User-selected npm or pnpm; TypeScript scaffolds in the current directory | 646403b | [0003](0003-pnpm-only-for-node-scaffolds.md) (e5badcf) |
| Hand-written `.gitignore`, copied MIT text, hardcoded author | ed4d9ac, 646403b, 7f32186 | [0004](0004-generator-preference-order.md) (ba697a6) |
| Fail on an existing directory | ed4d9ac, 646403b | [0005](0005-idempotent-partial-setup-mode.md) (ba697a6) |
| act verification mandatory | ed4d9ac, 646403b | [0006](0006-act-validation-is-optional-and-reported.md) (ba697a6) |
| All CI jobs always shipped, user deletes | ed4d9ac | [0007](0007-publishing-jobs-follow-scaffold-kind.md) (0707970, for kinds) |
| Commits carry the session's default `Co-Authored-By:` trailer | implicit until 3a67c8b | [0008](0008-scaffold-commit-messages-are-exact-no-attribution-trailers.md) (3a67c8b) |
| Raw `cmake -S . -B build -D…` flags in every C++ job; `CMakePresets.json` gitignored | ba697a6, 0707970 | [0009](0009-cpp-builds-are-driven-by-a-committed-cmakepresets-json.md) (7cb1c8f) |
| CMake 3.23 floor, explicit policy lines, vendored `Doxyfile.in` | 646403b, 0707970 | [0010](0010-cpp-templates-target-current-cmake.md) (7cb1c8f) |
| C++ format check against clang-format's LLVM fallback style | ba697a6 | [0011](0011-cpp-scaffolds-ship-a-clang-format.md) (5af7900) |

## Commit key

| SHA | Date | Subject |
| --- | --- | --- |
| 7f32186 | 2026-06-09 | Welcome to the project, Claude! (first root `CLAUDE.md`) |
| ed4d9ac | 2026-06-09 | Added new-rust-project skill |
| 646403b | 2026-06-09 | Added first pass project initialization skills (cpp, julia, typescript) |
| e5badcf | 2026-06-10 (landed 2026-07-04) | Finished typescript-init-default |
| ba697a6 | 2026-07-09 | Refactored the new-project skills so that the all basically do the same thing. Added new-haskell-project skill |
| 0707970 | 2026-07-09 | new-cpp-project: Added code coverage and docs in CI/CD for libraries only. |
| 167878f | 2026-07-26 | Updated new-project SKILL.md and CI/CD templates to use latest Node.js LTS version |
| c5577ac | 2026-07-26 | Added new-tauri-project skill |
| 3a67c8b | 2026-10-16 | Address 2026-10-16 ultrareview findings; misc skill updates (new-project: removed Claude attribution in commit messages) |
| 7cb1c8f | 2026-11-24 | new-project: Added the latest bells and whistles to the CMakeLists.txt templates (minimum version is 4.5) |
| 5af7900 | 2026-11-26 | new-project: new-cpp-project now scaffolds a .clang-format (Google style, 120 columns, 4-space indent) |

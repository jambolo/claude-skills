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

## Reversed designs

No ADR is superseded, but several first-pass designs were reversed by later commits and are recorded under "Alternatives considered" in the ADR that replaced them:

| Initial design | Commit | Replaced by |
| --- | --- | --- |
| Per-package-manager CI templates (`ci-npm.yml`, `ci-pnpm.yml`); no CI for C++ | 646403b | [0001](0001-shared-ci-cd-workflow-topology.md) (e5badcf, ba697a6) |
| Literal `node-version: 24` bumped by hand | e5badcf | [0002](0002-template-pins-are-a-baseline-refreshed-at-scaffold-time.md) (167878f) |
| User-selected npm or pnpm; TypeScript scaffolds in the current directory | 646403b | [0003](0003-pnpm-only-for-node-scaffolds.md) (e5badcf) |
| Hand-written `.gitignore`, copied MIT text, hardcoded author | ed4d9ac, 646403b, 7f32186 | [0004](0004-generator-preference-order.md) (ba697a6) |
| Fail on an existing directory | ed4d9ac, 646403b | [0005](0005-idempotent-partial-setup-mode.md) (ba697a6) |
| act verification mandatory | ed4d9ac, 646403b | [0006](0006-act-validation-is-optional-and-reported.md) (ba697a6) |
| All CI jobs always shipped, user deletes | ed4d9ac | [0007](0007-publishing-jobs-follow-scaffold-kind.md) (0707970, for kinds) |

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

# 0001. CI/CD ships as bundled workflow templates with one shared job topology

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** ed4d9ac, 646403b, e5badcf, ba697a6, 0707970, c5577ac

## Context

ed4d9ac shipped `new-rust-project` with `templates/ci.yml` and `templates/cd.yml` and documented them in two sections the skill has kept ever since, "CI behavior (encoded in the template)" and "CD behavior (encoded in the template)":

> - **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
> - **`build-and-test`** job: every trigger — … across an **OS matrix** (`ubuntu-latest`, `windows-latest`, `fail-fast: false`, per-OS cache key).
> - **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`, so `cargo fmt --check` and `cargo clippy -D warnings` run **only on pull requests**.
> - **`docs`** job: gated by `if: github.ref == 'refs/heads/master'` and `needs: build-and-test` … deploys it to GitHub Pages.
> - **`coverage`** job: gated by `if: github.ref == 'refs/heads/develop'` and `needs: build-and-test` … uploads to Codecov.
>
> `cd.yml` is the release-automation workflow. Triggers on push to `master` that touches `Cargo.toml`. … **`build`** job: … gate — never tag a broken master. **`release`** job … **if that tag doesn't already exist**, creates + pushes `v<version>`, then merges `master` into `develop` (`--no-ff`). Idempotent — re-running on an unchanged version is a no-op.

The same topology was then carried to every other scaffolder: Julia and TypeScript had the two-job form from 646403b; TypeScript gained docs/coverage/CD in e5badcf; C++ got `ci.yml` in ba697a6 and docs/coverage/CD in 0707970; Haskell arrived with the two-job form plus matrix and caching in ba697a6; Tauri (c5577ac) has build-and-test on a three-OS matrix, PR-gated lint, develop-only coverage, and the same CD shape keyed on `package.json`. The job names (`build-and-test`, `lint-and-format`, `docs`, `coverage`, `build`, `release`), the branch triggers, and the gating expressions are identical across languages; only the steps inside differ. The branch set and the master→develop back-merge encode a git-flow layout (`master` released, `develop` integration, `release/**` branches).

The workflow is a *template file* copied into the project rather than instructions to write YAML, and the skill body describes what the template does rather than repeating it, so the YAML is the single source of the behavior.

## Decision

Every scaffolder ships its CI (and, where the scaffold kind warrants it, CD) as bundled `templates/ci.yml` / `templates/cd.yml` that the skill copies to `.github/workflows/` with at most token substitution. All templates share one topology: push triggers on `master`, `develop`, `release/**` plus all pull requests; `build-and-test` on every trigger across an OS matrix; `lint-and-format` only on pull requests; `docs` only on `master` after build/test; `coverage` only on `develop` after build/test; PR-scoped `cancel-in-progress` concurrency. `cd.yml` watches the language manifest on `master`, re-runs build + test as a gate, tags `v<version>` if the tag does not exist, and merges `master` into `develop` with `--no-ff`. The `SKILL.md` documents the encoded behavior and an "Adjust per project" list instead of restating the YAML.

## Consequences

- Generated repos assume git-flow branch names and GitHub-hosted runners; a project on `main` or without `develop` must edit the triggers and drop the back-merge.
- The `docs` job requires GitHub Pages to be enabled and the `coverage` job a `CODECOV_TOKEN` secret; both are documented as setup obligations, and the `docs` job is listed under "Adjust per project" as removable.
- Adding a language means authoring a template that fits the topology (same job names and gates), which keeps the act verification steps and the `advent-of-code` table notes ("drop `docs`/`coverage` CI jobs") valid across languages.
- Which jobs a scaffold actually keeps depends on its kind — see [0007](0007-publishing-jobs-follow-scaffold-kind.md).
- Template action pins age; the refresh rule in [0002](0002-template-pins-are-a-baseline-refreshed-at-scaffold-time.md) exists because of this decision.
- The CD version source is per language (`cargo get`, `node -p`, the `VERSION` line of `project()`); Tauri additionally has to keep `tauri.conf.json` and both `Cargo.toml`s in step with `package.json` by hand.

## Alternatives considered

- **Per-package-manager templates** — 646403b shipped `ci-npm.yml` and `ci-pnpm.yml` for TypeScript; e5badcf collapsed them to one `ci.yml` when the skill went pnpm-only ([0003](0003-pnpm-only-for-node-scaffolds.md)).
- **No CI for C++** — 646403b's `new-cpp-project` produced no workflow; ba697a6 added `ci.yml` so that "all basically do the same thing".

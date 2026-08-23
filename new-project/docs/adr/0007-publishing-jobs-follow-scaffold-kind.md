# 0007. Publishing jobs (docs, coverage, CD release) follow the scaffold's kind: library gets them, application does not

**Status:** Accepted
**Date:** 2026-07-09
**Commits:** ed4d9ac, 0707970, ba697a6, c5577ac

## Context

The shared topology ([0001](0001-shared-ci-cd-workflow-topology.md)) has two tiers: `build-and-test` + `lint-and-format`, which make sense for any repo, and `docs` (Pages), `coverage` (Codecov), and `cd.yml` (tag + back-merge), which presuppose a public API, a test suite, and a versioned manifest. The first Rust skill shipped all of them and documented the toggle per project:

> - **`docs` job** (`ci.yml`) — on by default … Remove the entire `docs` job for a binary-only crate or any repo with no Pages setup.

0707970 ("new-cpp-project: Added code coverage and docs in CI/CD for libraries only") made the toggle a function of the scaffold's `kind` input instead of a post-hoc edit:

> - **Executable** — delete the entire `docs` and `coverage` jobs from `.github/workflows/ci.yml`; they only make sense for the library scaffold (Doxygen config, tests). Commit: … "Added GitHub Actions CI workflow".
> - **Library** — keep all four CI jobs, and also copy `templates/LIBRARY_TEMPLATE_cd.yml` to `.github/workflows/cd.yml` … Commit both together: … "Added GitHub Actions CI/CD workflows".

so one `ci.yml` template is trimmed by kind and the CD template is library-only (`LIBRARY_TEMPLATE_cd.yml`). ba697a6's Haskell skill carries a `kind` table (library + executable, executable, library) and notes the consequence for tests ("`cabal init` does not generate a test suite for an executable-only package … CI still works"). c5577ac applied the rule to an application scaffold that has no `kind` input at all:

> - **No `docs` job** — deliberate: this is a desktop application, not a library, so there is no API-docs site to publish … To publish API docs for the core crate or the frontend, lift the `docs` job from the `new-rust-project` or `new-typescript-project` CI template and enable GitHub Pages.

The same distinction governs lockfiles: the Rust rules ignore `Cargo.lock` "keep the entry for a library, delete it for an executable", while Tauri says "Do **not** ignore `Cargo.lock` or `pnpm-lock.yaml` — this is an application, so both lockfiles are committed."

## Decision

A scaffold's kind — library/package versus executable/application — decides which publishing jobs it ships with. Library scaffolds get `docs`, `coverage`, and `cd.yml`; application scaffolds get neither `docs` nor a CD release by default (Tauri keeps `coverage` because it has tests on both stacks) and commit their lockfiles. Where a skill has a `kind` input (C++, Haskell) the skill applies the rule when copying templates; where the scaffold is inherently one kind (Tauri — application; Rust and TypeScript — library by default) the skill documents what is omitted or removable under "Adjust per project" and names where to lift the job from.

## Consequences

- Commit messages differ by kind ("Added GitHub Actions CI workflow" vs "Added GitHub Actions CI/CD workflows"), which the partial-setup mode must respect.
- A single `ci.yml` template per skill holds the superset of jobs; the skill edits the copy rather than maintaining two templates (the C++ CD template is the one kind-specific file, named `LIBRARY_TEMPLATE_cd.yml` to say so).
- Rust and TypeScript default to the library tier, so an application built with them has to remove `docs` by hand; `advent-of-code`'s delegation note for Rust ("skip `cd.yml`, drop `docs`/`coverage` CI jobs") exists because of this default.
- "Adjust per project" sections are an obligation of every skill: each lists what was included or omitted by kind and how to flip it.

## Alternatives considered

- **Always ship every job and let the user delete** (ed4d9ac, Rust) — still the behavior for Rust and TypeScript, but for C++ it was replaced in 0707970 by trimming at scaffold time, since the executable scaffold has no Doxygen config or tests for the jobs to operate on.

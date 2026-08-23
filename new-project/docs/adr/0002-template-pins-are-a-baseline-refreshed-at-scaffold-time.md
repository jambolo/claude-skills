# 0002. Template version pins are a baseline the skill refreshes at scaffold time with `git ls-remote`

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** ed4d9ac, 646403b, e5badcf, 167878f, c5577ac

## Context

Workflow templates carry `uses: owner/action@vN` pins, the C++ `CMakeLists.txt` template carries FetchContent `GIT_TAG`s, and the Tauri `Cargo.toml` template carries crate requirements. Any of these is stale the day after it is written, and a skill repo has no Dependabot-style process (the Julia scaffold even disables the `Dependabot` PkgTemplates plugin). ed4d9ac set the rule for actions:

> The template `uses:` pins are a current-as-of-authoring baseline and may have gone stale. Before committing, resolve the **latest stable major version** of each versioned action and update its `uses:` … Resolve with `git ls-remote` (no `gh`, no auth):
>
> ```bash
> git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
> ```
>
> Take the highest stable semver (ignore tags containing `-`), pin to its major — `v4.2.2` → `actions/checkout@v4`. If `git ls-remote` is unavailable, read the resolved tag from `https://github.com/<owner>/<repo>/releases/latest`.
>
> Leave `dtolnay/rust-toolchain@stable` and `taiki-e/install-action@cargo-llvm-cov` as-is — they are pinned to a channel / tool name, not a version tag.

167878f ("Updated new-project SKILL.md and CI/CD templates to use latest Node.js LTS version") extended the rule in two directions. It applied it to the C++ FetchContent pins, with a different granularity:

> Unlike the workflow actions, FetchContent needs the full exact tag (e.g. `v1.17.0`), not just the major. … also inside the commented blocks, so enabling one later starts current.

and it replaced a literal Node pin that the skill had been told to bump by hand (e5badcf: "bump to the current active LTS major if it has moved past `24`") with a run-time alias: "`node-version: lts/*` needs no refresh — setup-node resolves the current Node LTS at run time." c5577ac applied the same idea to crates: "Refresh them to the latest stable releases with cargo itself … `cargo add tauri serde_json`."

Each `SKILL.md` lists exactly which pins to refresh and which to leave (Haskell: the GHC pin is substituted from `ghc --numeric-version` because cabal pins `base` to the scaffold-time compiler, so "latest" would be wrong there).

## Decision

Template pins are a current-as-of-authoring baseline, never the authority. Before committing a copied template the skill resolves the latest stable version of every *versioned* pin it lists — actions to their latest stable major, FetchContent tags to the exact latest stable tag, crates via `cargo add` — using unauthenticated `git ls-remote --tags` with the releases page as fallback. Pins that name a channel or tool (`@stable`, `lts/*`, `@cargo-llvm-cov`, Julia `version: '1'`) are left as written, and a pin that must match the local toolchain (GHC) is substituted from that toolchain, not from upstream. Where a run-time-resolving alias exists it is preferred over a literal that would need refreshing.

## Consequences

- Scaffolding needs network access to github.com; the fallback is a human-readable page, not an offline path.
- Each skill must keep an explicit list of refreshable pins and a list of exceptions; adding a step to a template means adding its action to the list.
- Templates in the repo are allowed to drift; correctness is established at scaffold time, so a template change is not needed merely because an action released a new major.
- Pinning to the major (`@v6`) rather than the exact tag trades reproducibility for automatic patch updates; FetchContent pins deliberately do not make that trade.
- A refresh can cross a major and break the template ("If this bumps tauri to a new major … expect template drift — fix what the compiler reports"); the skill accepts that as part of scaffolding.

## Alternatives considered

- **Hand-bumped literal Node version** (e5badcf, `node-version: 24` plus an instruction to check endoflife.date): replaced in 167878f by `lts/*`.
- **Upstream's own update tooling**: the Julia scaffold disables PkgTemplates' `CompatHelper`, `TagBot`, and `Dependabot` plugins in favor of the skill's own workflow (646403b), so no scaffold relies on bots to keep pins fresh.

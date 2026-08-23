# 0004. Generator preference order: native tooling, then npx generators, then bundled templates

**Status:** Accepted
**Date:** 2026-07-09
**Commits:** ba697a6, e5badcf, c5577ac

## Context

The first-pass skills (ed4d9ac, 646403b) wrote most artifacts by hand: the Rust and C++ `.gitignore`s were literal blocks in the skill, `LICENSE` was copied from `reference/mit-license.txt` with `<YEAR>` substituted and the author hardcoded (`CLAUDE.md`: "`Copyright (c) <year> John Bolton`"), and TypeScript shipped a frozen `templates/tsconfig.json`. Only Julia leaned on its generator (PkgTemplates), and even there the stock `Readme`, `GitHubActions`, `CompatHelper`, `TagBot`, and `Dependabot` plugins were disabled.

e5badcf moved TypeScript to `tsc --init` and explained why a generator beats a snapshot:

> `tsc --init` layers these flags over the current TypeScript version's recommended defaults (strict, declaration, nodenext modules, …), so the result tracks upstream best practice rather than a frozen snapshot. The flags are only the settings that diverge from those defaults.

ba697a6 generalized this into a family rule and gave every skill a "Tool preference" section:

> Generator preference order: **language-native tooling first** (`cargo`, `cabal init`, `PkgTemplates`, `tsc --init`), **npx generators second** (`npx gitignore <lang>`, `npx license MIT` — even in non-Node projects), **bundled templates / hand-written content last**. Reading author info from git config is fine.

In the same commit `.gitignore` generation switched to `npx gitignore <lang>` (the hand-written block kept only as the npx-unavailable fallback), the license to `npx license MIT` / `cabal init --license=MIT` / PkgTemplates `License(; name="MIT")` with the copyright line changed to `<git config user.name>`, and the new Haskell skill let `cabal init` generate "the `.cabal` manifest, `src/`/`app/`/`test/` starter sources, `CHANGELOG.md`, and the MIT `LICENSE`" so that it "bundles no source templates at all". C++ documents the exception: "There is no language-native project generator for CMake, so the CMakeLists templates above stay."

c5577ac shows the rule being consciously broken where a generator's output is wrong for the scaffold:

> Two deliberate deviations from the sibling skills: `tsconfig.json` comes from the bundled template, not `tsc --init`: a Vite app needs `moduleResolution: bundler` and `noEmit` … The Rust `.gitignore` entries are appended by hand, not via `pnpm dlx gitignore rust`: that generator ignores `Cargo.lock`, which is wrong for an application.

## Decision

For each artifact a scaffolder prefers, in order: the language's own generator; a generic npx/`pnpm dlx` generator (`gitignore`, `license`) — used even in non-Node projects; a bundled template or hand-written content only when neither exists or fails. Generated output is post-processed rather than replaced (patch `tsconfig.json`, append `.vscode/` to the generated `.gitignore`, verify the copyright line). Author and year come from git config. A skill that departs from the order says so and why in its "Tool preference" section.

## Consequences

- Scaffolds track upstream defaults over time instead of the skill's authoring date; the skill text describes deltas from defaults, not full files.
- `reference/mit-license.txt` is retained per skill as the npx-unavailable fallback only; `new-cpp-project` dropped its copy in e5badcf and the Julia skill gained one in ba697a6 for its partial-setup path.
- Every generator step needs a stated fallback and a verification step (the copyright line check exists because `npx license` reads npm config, not git config).
- Non-Node scaffolds depend on `npx` (Node) for `.gitignore` and `LICENSE`; the root `CLAUDE.md` lists `npm`/`npx` among the required tooling for that reason.
- Disabled generator plugins are an explicit list in the command (Julia `!Readme, !GitHubActions, …`) so the skill's own README and CI win over the generator's.

## Alternatives considered

- **Hand-written / bundled everything** (ed4d9ac, 646403b) — the initial state; replaced in ba697a6 to stop maintaining per-language `.gitignore` and config snapshots in the skill.
- **Hardcoded author** (`John Bolton` in 7f32186's conventions) — replaced by `git config user.name` in ba697a6.

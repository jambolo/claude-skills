# 0003. Scaffold delegates repo bootstrap to `new-<language>-project` skills, with an inline fallback

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** 2fd8754, ba697a6, e757c21

## Context

bb12e5f's scaffold created everything itself — "**Always create**: README.md … LICENSE — MIT license … Build configuration — `Cargo.toml` / `go.mod` / `package.json` / `CMakeLists.txt` …" — duplicating work that the `new-*-project` scaffolders in the same repo already do with templates, seeded commits, and CI workflows.

2fd8754 split scaffold into two phases and made delegation mandatory:

> The scaffold operation is built on top of the `new-<language>-project` scaffolder skills: when the project's language has one, that skill does the repo bootstrap (git history, .gitignore, license, README, build config, CI) and this skill only adds what is AoC-specific. Do not reimplement anything a scaffolder skill already does.
>
> Phase A — Bootstrap the repository: Check whether a `new-<language>-project` skill exists for the project's language. If it does, **invoke it via the Skill tool** — do not replicate its steps by hand.

A per-language table carries the notes needed for the delegated run (Rust: skip `cd.yml`, drop `docs`/`coverage` CI jobs; C++: executable variant; TypeScript: `mkdir` + `cd` first, pass pnpm/npm choice; Julia: identifier-safe package name; Haskell, added in ba697a6: library + executable kind). Languages without a scaffolder fall back to an inline five-step bootstrap that mirrors the shared scaffolder conventions (`git init` + empty "New repo" commit, `.gitignore`, MIT license, `README.md`, build config — one commit each).

The family `CLAUDE.md` (e757c21) restates this as the family's defining trait, and the root `CLAUDE.md` notes the reverse dependency: the scaffolders "also serve as the bootstrap layer for `advent-of-code` scaffolds, so behavior changes here propagate there" and "`advent-of-code`'s inline scaffold fallback follows [the scaffolder conventions] too."

## Decision

`scaffold` is Phase A (bootstrap) then Phase B (AoC layer). Phase A invokes the matching `new-<language>-project` skill through the Skill tool whenever one exists, passing the per-language notes from the table; otherwise it bootstraps inline following `new-project/CLAUDE.md`'s "Scaffolder conventions". Phase B adds only AoC-specific content (restructure, README rewrite, common library, day-1 stub, CI fix-up, `CLAUDE.md`), one commit per step. The bootstrap path taken is recorded as one line in the project's `CLAUDE.md`.

## Consequences

- `advent-of-code` has a runtime dependency on the `new-project` family being installed; a missing scaffolder silently degrades to the inline fallback (no CI, no templates).
- The per-language table must be extended when a scaffolder is added (ba697a6 precedent) and revisited when a scaffolder's options change — a cross-family coupling, and the reason the `description` names each scaffolder.
- Per-step commit discipline ("the seeded git history is intentional output") is inherited from the scaffolders and carried through Phase B, so a scaffolded AoC repo has one commit per artifact.
- The bootstrap result is always single-target and must be restructured in Phase B step 1 ([0001](0001-common-library-plus-independent-per-day-entry-points.md)); CI installed by the scaffolder must be fixed up in step 5.
- The README rewrite in Phase B step 2 is the one sanctioned exception to "Don't clobber existing work".

## Alternatives considered

Self-contained scaffolding (bb12e5f) — the skill created LICENSE, build config, and README itself. Reversed in 2fd8754 to avoid reimplementing the scaffolders.

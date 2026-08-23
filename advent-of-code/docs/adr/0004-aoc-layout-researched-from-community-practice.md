# 0004. The AoC layout is researched from community practice, not hardcoded, and the sources are recorded

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** 2fd8754, e757c21

## Context

bb12e5f gave `init` a hardcoded "Language-specific guidance" table of typical layouts and run commands (Rust: "Cargo workspace, one crate per day — `cargo run -p day01 -- --part 1`"; Python, Go, C/C++, Haskell, TypeScript likewise). That encoded one author's guesses and went stale as soon as a language's tooling shifted.

2fd8754 removed the table and replaced it with a research step in scaffold Phase B:

> **Research the structure, then restructure.** … **Do not hardcode the layout, guess from general principles, or ask the user to design it** — research how the AoC community actually structures projects in this language, then adopt the prevailing convention.
>
> Research (WebSearch / WebFetch): Search for AoC repos and templates in the language … Prefer well-starred templates and repos from people who have completed multiple years — they encode lessons a fresh design won't have. Check for language-specific AoC tooling that dictates structure (e.g. `cargo-aoc` for Rust, AoC runner packages on npm/PyPI). …
>
> Then choose the structure that best matches community practice **while still satisfying the contract** … If community practice conflicts with the contract on some point, keep the contract and note the deviation in CLAUDE.md.
>
> Record in CLAUDE.md (init operation) which sources informed the structure and why it was chosen, so later sessions reuse the decision instead of re-researching it.

The `init` guidance was rewritten to match: "For an existing project, the layout and run command are facts to read out of the repo, not choices to make. For a brand-new project, they come from the structure research done during scaffold … CLAUDE.md should document the chosen structure *and* cite where it came from."

The family `CLAUDE.md` (e757c21): "the AoC-specific layout is **researched from community practice** (well-starred repos, templates, dominant tooling) rather than hardcoded — the chosen structure and its sources are recorded in the generated project's CLAUDE.md."

## Decision

For a new project, scaffold Phase B step 1 researches the prevailing AoC layout for the language (well-starred repos, templates, dominant tooling) with WebSearch/WebFetch, adopts it subject to the contract ([0001](0001-common-library-plus-independent-per-day-entry-points.md), [0002](0002-aoc-project-contract-stated-once-facts-vs-procedure.md)) and the bootstrap skill's toolchain/CI, and writes the chosen structure plus its sources into the project's `CLAUDE.md`. The skill itself carries no per-language layout table. The user is not asked to design the layout.

## Consequences

- `scaffold` needs web access; without it the research step cannot run as written.
- Layout is decided once per project and then becomes a fact in `CLAUDE.md`; later `stub`/`run` sessions must not re-derive it.
- Two projects in the same language may end up with different layouts if community practice moved between scaffolds; the recorded sources explain why.
- The skill stays language-agnostic without a maintenance burden per language.

## Alternatives considered

A hardcoded per-language layout/run-command table (bb12e5f) — removed in 2fd8754 in favor of research. Asking the user to design the layout is explicitly rejected in the same commit.

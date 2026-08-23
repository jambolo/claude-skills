# 0001. Common library plus one independent entry point per day

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** bb12e5f, 2fd8754

## Context

AoC repos in the wild range from one monolithic binary with a day dispatcher to fully separate programs per day. The skill had to pick a structural invariant that every language can satisfy and that `stub` can extend mechanically.

bb12e5f scaffold step 3 requires a common library providing "Argument parsing … returns day number, part, and the input filename" and "Data loaders for: single string, lines, comma-separated integers, character grid … integer grid"; step 4 adds a day-1 stub that "Import[s] and call[s] the common library's setup function". "Common pitfalls" states:

> **Keep days independent.** Don't add shared state between days; the common library is the only cross-day code.

2fd8754 promoted this to the first clause of the contract:

> **Structure** — a shared common library plus one runnable entry point per day. Days are independent: the common library is the only cross-day code.

and Phase B step 1 notes "The bootstrap skills produce a single-target project; an AoC project needs a common library plus one entry point per day."

## Decision

Every managed project is a shared common library (argument parsing for the contract flags, banner printing, and the five standard data loaders) plus one runnable entry point per day. Days never depend on each other. Each day directory holds empty `input.txt` and `example.txt`; each stub is wired into the build system and is stylistically indistinguishable from existing days.

## Consequences

- `stub` is a copy-and-register operation, not a design operation; its only creative input is the existing days' style.
- Bootstrap output from `new-*-project` (single target) must always be restructured in scaffold Phase B step 1, and any CI the bootstrap installed must be fixed up for the multi-target layout (Phase B step 5).
- Community layouts researched under [0004](0004-aoc-layout-researched-from-community-practice.md) are filtered by this invariant: "If community practice conflicts with the contract on some point, keep the contract and note the deviation in CLAUDE.md."
- "Wire it into any dispatch mechanism if monolithic" in the `init` guidance tolerates a monolithic *runner* as a realization, as long as days remain independent code.

## Alternatives considered

None recorded.

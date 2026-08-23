# 0002. The AoC project contract is stated once in the skill; generated CLAUDE.md holds facts, not procedure

**Status:** Accepted
**Date:** 2026-06-09
**Commits:** 2fd8754, a3a7d2f

## Context

bb12e5f scattered the cross-language invariants (flags, banner, answer line, README table, days-independent rule) across the four operations and the pitfalls list, and told `init` to copy some of them into each project's `CLAUDE.md`:

> **How to build and run a day** … What the banner output looks like (`=== Day <N>, part <P> ===`)
> **How to verify answers** — point to README.md table format and explain the `run` operation (see Operation 4).

That put the same rules in N project repos plus the skill, with nothing keeping them aligned. 2fd8754 ("Finished advent-of-code skill") introduced a single contract section and an explicit placement rule:

> Every project this skill manages satisfies the same contract, regardless of language. It is stated once, here; the operations below reference it instead of restating it, and generated CLAUDE.md files document only how the project *realizes* it (exact commands, paths, types) plus any deviations.
>
> CLAUDE.md records **project facts** — commands, paths, types, APIs, conventions. It must not restate **operation procedure** (how to stub, run, verify) or **contract semantics** (flag meanings, banner and answer formats, the days-independent rule) — those live in this skill and would drift in per-repo copies. Two-sided test: would the sentence be identical in every AoC project? It belongs in this skill. Does it mention a tool, file, type, or command of this repo? It belongs in CLAUDE.md.

The contract as fixed by 2fd8754:

- **Flags** — `--part <1|2>` (default 1) and `--example`.
- **Output** — banner `=== Day <N>, part <P> ===`; answer as the last stdout line `Answer: <value>`.
- **Structure** — see [0001](0001-common-library-plus-independent-per-day-entry-points.md).
- **Answers** — one `## Day <N>` section per day in README.md holding a `| Part | Answer |` table; a blank cell means unsolved.

bb12e5f's run step had been looser ("typically the last non-empty line, or a line matching `Answer: <value>`"); the contract makes `Answer: <value>` mandatory and `-e` as a short flag was dropped.

## Decision

One "The AoC project contract" section in `SKILL.md` is the sole statement of the cross-project invariants. Operations reference it by name. The `init` operation writes only project-specific *realizations* of the contract into a project's `CLAUDE.md` (exact commands, how flags are passed, paths, types) plus explicit deviations; it must omit contract-identical sections ("Answer locations — only if the project deviates … otherwise omit this section entirely. Never describe the verify procedure itself"). When updating an existing `CLAUDE.md`, `init` deletes prose that restates skill procedure.

## Consequences

- Contract changes are made in one place and propagate to every project on the next `init`/`run`; no per-repo copies to chase.
- "Where CLAUDE.md is silent, the contract formats apply" — silence in a project's `CLAUDE.md` is meaningful, so `init` must not pad sections defensively.
- Changing the flags, banner, or `Answer:` format is a **major** version bump (changed artifact format, per the root `CLAUDE.md` versioning rule) and can break `run` on projects built under the old contract unless their `CLAUDE.md` records a deviation.
- This is the opposite strategy from the `project-management` family, whose "Shared model" section is duplicated verbatim across three `AGENT.md` files. Here the consumers are generated project files, not sibling skills, so single-source wins.
- a3a7d2f's rename of `Operation N` references to operation names applies inside the contract's cross-references too.

## Alternatives considered

The bb12e5f approach — restating procedure and formats in each generated `CLAUDE.md` — was the initial design and was reversed the same day, for the stated reason that per-repo copies "would drift".

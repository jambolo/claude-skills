# Architectural Decision Records — `advent-of-code` family

Decisions that shape the `advent-of-code` skill, numbered in the order they were made (commit date). The family is a single instruction-only skill (`advent-of-code/advent-of-code/SKILL.md`) with no agents, templates, or scripts.

| # | Title | Status | Date | Superseded by |
| --- | --- | --- | --- | --- |
| [0001](0001-common-library-plus-independent-per-day-entry-points.md) | Common library plus one independent entry point per day | Accepted | 2026-06-09 | — |
| [0002](0002-aoc-project-contract-stated-once-facts-vs-procedure.md) | The AoC project contract is stated once in the skill; generated CLAUDE.md holds facts, not procedure | Accepted | 2026-06-09 | — |
| [0003](0003-scaffold-delegates-bootstrap-to-new-language-project-skills.md) | Scaffold delegates repo bootstrap to `new-<language>-project` skills, with an inline fallback | Accepted | 2026-06-09 | — |
| [0004](0004-aoc-layout-researched-from-community-practice.md) | The AoC layout is researched from community practice, not hardcoded, and the sources are recorded | Accepted | 2026-06-09 | — |
| [0005](0005-puzzle-inputs-are-not-republished-from-public-repos.md) | Every day has `input.txt` and `example.txt`; whether `input.txt` is committed is decided once, at scaffold | Accepted | 2026-08-24 | — |
| [0006](0006-run-verifies-real-input-answers-only.md) | Run verifies real-input answers only: example runs, failed runs, and stub output never reach the answer table | Accepted | 2026-08-24 | — |

## Reversed designs

No ADR is superseded, but three initial designs from bb12e5f were reversed the same day in 2fd8754 and are recorded under "Alternatives considered" in the ADR that replaced them:

| Initial design (bb12e5f) | Replaced by |
| --- | --- |
| `init` copied procedure and formats into each project's CLAUDE.md | [0002](0002-aoc-project-contract-stated-once-facts-vs-procedure.md) |
| `scaffold` created LICENSE, build config, and README itself | [0003](0003-scaffold-delegates-bootstrap-to-new-language-project-skills.md) |
| Hardcoded per-language layout/run-command table | [0004](0004-aoc-layout-researched-from-community-practice.md) |

## Commit key

| SHA | Date | Subject |
| --- | --- | --- |
| bb12e5f | 2026-06-09 | Added advent-of-code skill |
| 2fd8754 | 2026-06-09 | Finished advent-of-code skill |
| ba697a6 | 2026-07-09 | Refactored the new-project skills … Added new-haskell-project skill |
| e757c21 | 2026-07-30 | Cleaned up Claude.md (family CLAUDE.md created) |
| a3a7d2f | 2026-08-22 | Renamed some poorly named skill operations. |
| 528c6df | 2026-08-24 | advent-of-code: Cleaned up the skill |
| 3a67c8b | 2026-10-16 | Address 2026-10-16 ultrareview findings; misc skill updates (advent-of-code: TypeScript delegation note corrected) |

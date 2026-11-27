# 0020. The planner reads no other plan's artifacts, and reads narrowly

**Status:** Accepted
**Date:** 2026-11-27
**Commits:** bd8ab91, 98cedf7

## Context

The planner's cost is its context re-read on every turn: in five recorded runs on one project, 33–79 turns at a peak of 209–391k tokens, about 43% of cost in cache reads. Every one of those runs opened the previous milestone's brief (63–103 KB) two or three times, and briefs grew from 32 KB at milestone 1 to 116 KB at milestone 17, each modelled on the one before. Nothing in the planner's definition asked for that read; the earlier brief sits in the artifacts directory and looks like the obvious template.

## Decision

- **Other plans' artifacts are not input.** The planner never opens the brief, roadmap, ledger, or step files of another plan, whole or in part, at HEAD or in history. The templates in its own definition are the format; facts come from the prompt, the files the prompt names, and the live source. The one exception is an artifact the prompt names by path.
- **Read narrowly.** Locate first, then read the lines needed; a document cited by section is read as that section only; no lines are loaded twice; independent lookups go in one command with capped output.

## Rationale

Measured by replaying the planner on one milestone (the smallest recent one), four runs per arm, each change alone against the unchanged planner:

| | Cost USD (range) | Turns | Cache read | Brief | Other-plan reads |
| --- | --- | --- | --- | --- | --- |
| Unchanged | 3.93 (3.70–4.13) | 39.5 | 4.17M | 57.6 KB | 3.5 |
| No other plan's artifacts | 2.05 (1.94–2.23) | 28.2 | 1.98M | 26.7 KB | 0 |
| Read narrowly | 2.71 (1.91–3.35) | 41.0 | 3.20M | 37.9 KB | 3.2 |

- Neither range overlaps the unchanged planner's. The first change cuts cost 48%, the second 31%.
- The previous brief had been a template for thoroughness as well as a source of facts: without it the brief is half the size (about 10 project DoD items against about 20), and still carries every DoD item of the milestone.
- The saving carries downstream. The decomposer cost 1.03–1.21 USD on the thinner plans against 1.47–2.01 USD on the unchanged planner's, and produced the same step shape (three `standard`, one `lite`).
- The thinner plans work. Phase 1 of three of them (two from the first change, one from the second) was supervised with real builds beside one control: each completed 4 of 4 steps with no retry or revision and passed the milestone's Definition of Done from the project plan, which no planner run wrote.

## Consequences

- A fact that held in an earlier milestone reaches the planner only through the prompt, the project's own documents (`CLAUDE.md`, design notes), or the source. `lead-developer`'s prompt already carries a "context from earlier milestones" paragraph; a convention that lives only in old briefs is now lost unless it is moved to one of those places.
- Briefs stop growing by inheritance. A brief is as thorough as the prompt and the source make it, not as thorough as its predecessor.
- The two changes were measured separately. Their combined effect is not measured; both act on the same cached context, so it is less than the sum.
- The evidence is one milestone and one supervised plan per arm (two for the first change). It shows the thinner plans can work, not how often they fail.

## Alternatives considered

- **Give the planner a digest of the previous brief**: keeps the inheritance that inflated the briefs, and needs something to write the digest.
- **Move phase-only material from the brief into a `### Phase <N> material` subsection of the roadmap** (built and measured, not adopted): planner cost −8%, within noise. It moved the bytes (brief 26.8 KB, roadmap 32.6 KB), but every run planned one phase, so no phase was spared another's material and the decomposer loads the same total. Untested on a multi-phase milestone.
- **A `plan-seed.sh` script that checks the brief and roadmap, seeds the ledger, and commits** (built and measured, not adopted): planner cost −9%, within noise. Seeding is a few turns at the end of the run; the cost is in the reading before it.

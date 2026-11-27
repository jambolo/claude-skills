# 0005. Every day has `input.txt` and `example.txt`; whether `input.txt` is committed is decided once, at scaffold

**Status:** Accepted
**Date:** 2026-08-24
**Commits:** 528c6df

## Context

The contract ([0002](0002-aoc-project-contract-stated-once-facts-vs-procedure.md)) defined the `--example` flag as "read `example.txt` instead of `input.txt`" but never stated the input files as a contract item, and said nothing about whether they belong in git. Advent of Code asks that puzzle inputs not be republished, so a skill that scaffolds a repo and commits every stub was, by default, committing the user's real input to what may be a public repository.

528c6df ("advent-of-code: Cleaned up the skill") added an **Inputs** clause to the contract:

> - **Inputs** — every day directory holds `input.txt` (the real puzzle input) and `example.txt` (the sample from the puzzle text). Advent of Code asks that puzzle inputs not be republished: for a public repo, gitignore `input.txt` and record that in CLAUDE.md; for a private one, committing it is fine. Decide this once, at scaffold, and ask if the user hasn't said.

and extended the init operation's Conventions list to record "whether `input.txt` is committed or gitignored".

## Decision

The two input files per day are part of the AoC project contract. Whether the real input is tracked is a per-project decision made once, at scaffold: gitignored for a public repo, committed if the repo is private, and the user is asked when they have not said. The outcome is a project fact and is recorded in the generated `CLAUDE.md`, so later stub and run operations follow it without asking again.

## Rationale

"Advent of Code asks that puzzle inputs not be republished" (`SKILL.md`).

## Consequences

- A public AoC repo scaffolded by the skill does not publish puzzle inputs; a clone of it has empty or absent `input.txt` files, and the run operation's failure handling ([0006](0006-run-verifies-real-input-answers-only.md)) names a missing input as the likely cause.
- The stub operation commits "code, input files, build wiring, and README section" as one commit; with `input.txt` ignored, that commit carries only `example.txt`.
- The skill asks one more question at scaffold when visibility is unstated.
- The decision lives in `CLAUDE.md` and `.gitignore`, not in the skill, consistent with the facts-versus-procedure split in 0002. A project adopted through init rather than scaffold records whatever it already does.

## Alternatives considered

- **Always commit inputs** (the implicit behavior before 528c6df): simplest, and wrong for public repos.
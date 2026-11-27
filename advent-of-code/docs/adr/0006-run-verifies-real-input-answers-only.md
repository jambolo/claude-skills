# 0006. Run verifies real-input answers only: example runs, failed runs, and stub output never reach the answer table

**Status:** Accepted
**Date:** 2026-08-24
**Commits:** 528c6df

## Context

The run operation compares a day's output with the answer table in `README.md` and offers to record an answer whose cell is blank. As first written it had one closing line for variations — "If the user asks for the example run or a single part, pass the contract flags (`--example`, `--part <N>`) accordingly" — and one rule for a blank cell: "report the output and ask whether to write it to README.md". That left three ways to put a wrong value in the table or a wrong verdict in the report: an example answer compared with (or written as) the real one, a crashed or input-less run treated as a mismatch, and a fresh stub's placeholder return offered as an answer.

528c6df rewrote the operation around those cases:

> **Example runs are not verified.** If the request is for the example input, run with `--example`, report the banner and answer, and stop … README answer tables track real-input answers only, so there is no expected value to compare against, no ✓/✗ verdict to give, and an example answer must never be written into a day's answer table.

> **A failed run is not a wrong answer.** If a run exits non-zero, prints no `Answer:` line, or has to be killed for running too long, stop processing that part: report the exit code with stdout and stderr, leave its `Got` cell as `—` … Name the failure — build error, runtime panic, or missing puzzle input — since the fix differs.

> Before offering, verify the answer is real: the part's solver must contain actual logic rather than the stub's placeholder return, and `input.txt` must be non-empty. Judge by solver source and input file, never by the value — `0` is a legitimate answer from a real solver.

It also scoped requests: a single-part request runs and reports only that part, and a request naming no day "runs every day whose `input.txt` is non-empty, one table per day".

## Decision

The README answer table holds real-input answers and nothing else, and the run operation protects it:

- An `--example` run is reported and stops; it is never compared, never given a verdict, never written.
- A run that fails, prints no `Answer:` line, or is killed is reported as a failure with its cause, not as a mismatch, and does not proceed to the write-back step.
- A blank cell is offered for filling only when the solver has real logic and `input.txt` is non-empty, judged from the source and the file, never from the value; on yes, the cell is filled and committed.
- The scope of a run follows the request: one part, one day, or every day that has input.

## Rationale

From `SKILL.md`: the answer tables "track real-input answers only", so an example run has nothing to be compared with; a failure is named "since the fix differs"; and the value is not evidence because "`0` is a legitimate answer from a real solver".

## Consequences

- ✓/✗ in a run report means exactly "matches the recorded real-input answer"; every other outcome has its own wording.
- The run operation has to read solver source before offering a write, a small cost for not recording a stub's `0`.
- "Check my answers" skips days with empty input, which is the normal state of a public repo's fresh clone ([0005](0005-puzzle-inputs-are-not-republished-from-public-repos.md)), instead of reporting them as failures.
- There is nowhere to record expected example answers; verifying against the puzzle text's sample stays manual.
- When no run command can be found in `CLAUDE.md`, build files, or existing days, the skill asks and offers to record it via init rather than guessing.

## Alternatives considered

- **One flag-passing sentence and an unconditional offer to write** (2fd8754 through a3a7d2f): left the three failure modes above to the model's judgment.
- **Reject suspicious values (`0`, empty)**: rejected in the text itself; the value is not evidence, the solver and input are.

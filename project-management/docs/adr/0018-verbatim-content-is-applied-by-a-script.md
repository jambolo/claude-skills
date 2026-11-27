# 0018. Verbatim content travels in a step's `apply` block and is applied by `step-apply.sh`, never retyped

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** 60e3661

## Context

A `lite` step gives its content verbatim ([0014](0014-lite-steps-go-to-a-haiku-worker.md)). The decomposer wrote that content into `actions`, with instructions about line endings and wrapping, and the worker typed it again into the file. The text was paid for twice as output tokens, and a model that copies by typing can change it, which the acceptance hash then catches at the cost of a retry.

## Decision

- A step file has an optional `apply` block of operations: `@@ replace <path>` (`@old` / `@new`), `@@ insert-after` and `@@ insert-before <path>` (`@anchor` / `@text`), `@@ append <path>`, `@@ create <path> [eol=crlf]`, ended by `@@ end`. A content line that starts with `@` is written `\@`.
- `step-apply.sh --worktree <w> --step <file>` validates every operation against the current files and writes nothing unless all apply. It keeps each file's line endings and prints `APPLIED <n> operation(s)` and `FILE <path> lines=<n> md5=<md5 with LF endings>`, or `FAIL` with `DEFECT` lines.
- The worker runs it once, before `actions`, and never types that content itself. A `FAIL` is reported as `status: fail`, not repaired by hand.
- The decomposer dry-runs it with `--check` and takes the line counts and hashes for `acceptance_expect` from its output.
- A step whose whole work is its `apply` block is `tier: lite` with a one-line `actions`.

## Rationale

- Decomposer cost fell about 10% on both benchmark phases (0.77 against 0.85 USD; 1.91 against 2.09 USD), and step files were 32% smaller on the documentation phase, where the line-ending and typing instructions disappear.
- 12 of 12 `apply` steps passed first time on the documentation phase, with documents byte-identical to the recorded result.
- Supervising the resulting steps on the code phase cost 0.80 USD against 1.09 USD, on two runs per arm.

## Consequences

- The step schema gains a field with its own small syntax, parsed by one script (perl is required).
- A step whose `apply` edits a file that an earlier pending step creates cannot be dry-run.
- On a code phase only one or two steps carry an `apply` block; the saving scales with how much of a phase is verbatim.

## Alternatives considered

- **A unified diff in the step file**: hunk headers and context lines must be exactly right; exact-text anchors are simpler to write and fail loudly.
- **Have the worker copy with a heredoc**: still output tokens for the whole text, and still typed.

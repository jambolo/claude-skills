# smoke — Brief

## Goal
Add two small bash scripts, a test runner that exercises them, and a usage section in the
README, so the pipeline's mechanics (parallel worktrees, dependencies, verification,
merge, ledger, phase DoD) are exercised end to end in minutes.

## Context
- Repository: a bash project with no build step. `README.md` exists at the root.
- Scripts live in `src/` (created by phase 1) and are run as `bash src/<name>.sh`.
- The test runner lives in `test/run.sh` (phase 2) and is run from the repo root.
- Nothing is executable by file mode; always invoke with `bash`.

## Constraints
- bash only; no other languages, no package managers.
- Every script's first line is `#!/usr/bin/env bash`.
- Output is exact: no trailing punctuation or extra whitespace.

## Assumptions
- `bash` and `git` are on PATH.

## Out of scope
- Error handling, argument validation, documentation beyond the README usage section.

## Definition of Done (project)
```dod
# greet prints a greeting
cmd: bash src/greet.sh pipeline
expect: hello, pipeline
# count prints the argument count
cmd: bash src/count.sh x y
expect: 2
# the test runner passes
cmd: bash test/run.sh
expect: ok
# README documents usage
cmd: grep -c '^## Usage' README.md
expect: 1
```

# smoke — Roadmap

Phase 1 creates the two scripts in parallel; phase 2 adds a test runner that depends on
both and a README section that depends on one, again in parallel.

## Phase 1 — Scripts
- **Objective:** `src/greet.sh` and `src/count.sh` exist and print the expected output.
- **Scope:** `src/`
- **Depends on:** nothing
- **Definition of Done (phase):**
  ```dod
  # greet prints a greeting
  cmd: bash src/greet.sh pipeline
  expect: hello, pipeline
  # count prints the argument count
  cmd: bash src/count.sh x y
  expect: 2
  ```
- **Risks:** none; the steps are deliberately trivial.

## Phase 2 — Test runner and docs
- **Objective:** `test/run.sh` exercises both scripts; `README.md` documents usage.
- **Scope:** `test/`, `README.md`
- **Depends on:** phase 1
- **Definition of Done (phase):**
  ```dod
  # the test runner passes
  cmd: bash test/run.sh
  expect: ok
  # README documents usage
  cmd: grep -c '^## Usage' README.md
  expect: 1
  ```
- **Risks:** none.

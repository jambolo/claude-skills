# Step 2a

- id: 2a
- depends_on: [1a, 1b]
- route: mechanical
- tier: standard
- objective: Add test/run.sh, which runs both scripts and prints "ok" when their output is correct.
- files_in_scope:
    - test/run.sh
    - docs/smoke-2a-report.md
- context: |
    The repository is a tiny bash project with no build step. Phase 1 produced
    src/greet.sh (prints "hello, <first argument>") and src/count.sh (prints the number
    of arguments). Both are run as `bash src/<name>.sh` from the repository root. The
    test runner is run the same way: `bash test/run.sh` from the root. Every script's
    first line is `#!/usr/bin/env bash`.
- actions: |
    1. Assert the base: both src/greet.sh and src/count.sh must exist. If either is
       absent, STOP and report "missing base" in the report file — do not create them.
    2. Create test/run.sh: the shebang line, then logic that runs `bash src/greet.sh a`
       and `bash src/count.sh 1 2`, prints "ok" and exits 0 when the outputs are exactly
       "hello, a" and "2", and otherwise prints "fail" and exits 1.
    3. Run the acceptance command from the worktree root and confirm its output.
- acceptance_cmd: |
    bash test/run.sh
- acceptance_expect: |
    ok

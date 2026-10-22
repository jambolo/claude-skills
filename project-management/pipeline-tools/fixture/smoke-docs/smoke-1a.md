# Step 1a

- id: 1a
- depends_on: []
- route: mechanical
- tier: standard
- objective: Add src/greet.sh, which prints "hello, <first argument>".
- files_in_scope:
    - src/greet.sh
    - docs/smoke-1a-report.md
- context: |
    The repository is a tiny bash project with no build step. Scripts live in src/ and
    are run with bash (they are not executable by mode). src/ does not exist yet; create
    it. Every script's first line is `#!/usr/bin/env bash`. Output must be exact: no
    trailing punctuation.
- actions: |
    1. Create src/greet.sh with exactly two lines: the shebang line, then a line that
       prints "hello, " followed by the first argument.
    2. Run the acceptance command from the worktree root and confirm its output.
- acceptance_cmd: |
    bash src/greet.sh world
- acceptance_expect: |
    hello, world

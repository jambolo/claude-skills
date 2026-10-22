# Step 1b

- id: 1b
- depends_on: []
- route: mechanical
- tier: lite
- objective: Add src/count.sh, which prints the number of arguments it received.
- files_in_scope:
    - src/count.sh
    - docs/smoke-1b-report.md
- context: |
    The repository is a tiny bash project with no build step. Scripts live in src/ and
    are run with bash (they are not executable by mode). src/ may not exist yet; create
    it if needed. Output must be exact: a bare number, no other text.
- actions: |
    1. Create src/count.sh with exactly this content (two lines):
       #!/usr/bin/env bash
       echo "$#"
    2. Run the acceptance command from the worktree root and confirm its output.
- acceptance_cmd: |
    bash src/count.sh a b c
- acceptance_expect: |
    3

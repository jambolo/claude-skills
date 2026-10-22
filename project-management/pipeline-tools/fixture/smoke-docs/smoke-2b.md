# Step 2b

- id: 2b
- depends_on: [1a]
- route: mechanical
- tier: standard
- objective: Add a "## Usage" section to README.md showing how to run src/greet.sh.
- files_in_scope:
    - README.md
    - docs/smoke-2b-report.md
- context: |
    README.md exists at the repository root with a title and one paragraph. Phase 1
    produced src/greet.sh, run as `bash src/greet.sh <name>` from the repository root.
- actions: |
    1. Assert the base: src/greet.sh must exist. If absent, STOP and report "missing
       base" in the report file.
    2. Append to README.md a level-2 heading exactly `## Usage`, a blank line, and one
       indented code line showing `bash src/greet.sh <name>`. Change nothing else.
    3. Run the acceptance command from the worktree root and confirm its output.
- acceptance_cmd: |
    grep -c '^## Usage' README.md
- acceptance_expect: |
    1

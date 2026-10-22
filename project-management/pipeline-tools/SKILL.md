---
name: pipeline-tools
version: 1.2.0
description: >
  Scripts, benchmark fixtures, and the headless benchmark harness for the
  project-management pipeline (planner → decomposer → supervisor → worker). The
  pipeline agents call the scripts by path from
  `~/.claude/skills/pipeline-tools/scripts/`, so install this skill wherever those
  agents run. Invoke it directly only when the user asks to "run the pipeline smoke
  test", "make the pipeline fixture", "self-test the pipeline scripts", "check the
  pipeline scripts", "benchmark the pipeline", "compare pipeline configurations", or
  "exercise the lead developer end to end".
  Not for planning or executing real work (that is `lead-developer`), and not a
  general git-worktree or test-runner helper.
---

# Pipeline tools

## Scripts

All are bash (`#!/usr/bin/env bash`), run as `bash <path> ...`. Each prints its verdict or
record lines first and exits 0 on success, 1 on a verdict failure (first line `FAIL: ...`
or `VERDICT FAIL`), 2 on usage or an unparsable input. `$S` below is
`$HOME/.claude/skills/pipeline-tools/scripts`.

| Script | Used by | Does | Prints |
| --- | --- | --- | --- |
| `wave-create.sh --repo <r> --plan <p> --worktrees <d> [--ancestor <sha>]... <id>...` | supervisor | Refuses a dirty tree or a dependency SHA not in HEAD; creates `wt/<p>-<id>` worktrees at BASE = HEAD, recreating stale ones; verifies each worktree's HEAD. | `BASE <sha>`, `WORKTREE <id> <path>`, `RECREATED <id>` |
| `step-verify.sh --worktree <w> --base <sha> --step <file> [--in-tree]` | supervisor | Checks one commit since BASE, a clean tree, changed paths within `files_in_scope` with the report present, and `acceptance_cmd` against `acceptance_expect`. | `VERDICT PASS` or `VERDICT FAIL`, `REASON ...`, `COMMITS n`, `CHANGED <path>`, `ACCEPTANCE exit=...`, output tail |
| `step-merge.sh --repo <r> --plan <p> --id <id> --ledger <path> --worktree <w> or --in-tree [--status done or failed] [--tokens n] [--tool-uses n] [--wall s] [--retries n]` | supervisor | Merges `wt/<p>-<id>` with `merge(<p>): step <id>`, rewrites the step's ledger row, commits `supervise(<p>): record step <id>`, removes the worktree and branch. Aborts a conflicting merge and exits 1. | `MERGED <id> <sha>`, `RECORDED <id> <status>` |
| `dod-run.sh --file <md> [--heading <text>] [--cwd <dir>]` or `--checks <file>` | supervisor, lead-developer | Runs the `dod` block after the first heading line containing `<text>`. | `PASS`, `FAIL`, or `MANUAL` per item; `DOD PASS n/n` or `DOD FAIL k of n failed` |
| `find-formatter-gates.sh --repo <r> --artifacts-dir <d or .> --pattern <glob>` | planner, lead-developer | Detects Prettier, markdownlint-cli2, markdownlint-cli, dprint, and pre-commit; reports whether the artifacts are already ignored and the exact entry to add. | `GATE <tool> config=... ignore=... covered=yes or no entry=...`, or `NONE` |
| `make-fixture.sh [--fixture smoke or smoke-undecomposed or mid or project] <dir>` | this skill | Creates a fixture repository (see Fixtures). | `FIXTURE <path>`, `KIND`, `PLAN`, `BRANCH`, `PHASES <n>`, `STARTING_COMMIT <sha>`, the procedure |
| `bench-run.sh --config <label> [--fixture kind] [--set agent.field=value]... [--repeat n] [--yes]` | this skill | Runs every phase of a fixture headless under one configuration and appends a row per run to a TSV (see Benchmark). | `RUN ...` per phase, `ROW ...` per run, `RESULTS <tsv>` |
| `bench-summary.sh [<tsv>]` | this skill | Per-configuration means: cost, duration, DoD pass rate, phases, retries, revisions, tokens. | one line per config, then the decision rule |
| `selftest.sh` | this skill | Exercises every script above with a bash-simulated worker; no model, no spend. | `ok` or `FAIL` per assertion; `selftest: n passed, m failed` |

Step-file fields the scripts parse (the decomposer's step schema): `- files_in_scope:`
with `    - <path>` entries, and `- acceptance_cmd: |` and `- acceptance_expect: |` blocks
whose lines are indented four spaces. `acceptance_expect` is exact stdout (trailing
newlines ignored, exit status 0 required) or the single line `exit 0`.

`dod` block records: `# <name>` then `cmd: <one shell line>` and `expect: <exact stdout>`
or `expect: exit 0`; or `# <name>` then `manual: <what a person must confirm>`. Manual
items print `MANUAL` and never fail the run.

## Fixtures

| Kind | Plan, branch | Phases | What it exercises |
| --- | --- | --- | --- |
| `smoke` | `smoke`, `smoke-run` | 2, four pre-written steps (one `tier: lite`) | supervisor loop, workers, worker-lite dispatch, parallel waves, dependencies; minutes, cents |
| `smoke-undecomposed` | `smoke`, `smoke-run` | 2, no step files | the above plus the decomposer on a trivial brief |
| `mid` | `textstat`, `textstat-run` | 3, no step files, one open design decision in phase 2 | the decomposer at realistic size (about ten steps), a `judgment` route, an edited-in-place file across phases, three phase gates |
| `project` | `notes`, `develop` | no plan: `SYNOPSIS.md` with two milestones | the `lead-developer` skill end to end — interview, project plan with `dod` blocks, planner, milestone branches, `dod-run.sh` at Evaluate, archive tags, squash-merge; interactive only |

Every plan fixture is a fresh git repository with the plan artifacts committed on the
working branch and `starting-commit` set to the project's initial commit. The `project`
fixture has no artifacts: an initial commit, an empty `docs/`, and a `develop` branch
checked out, which the lead developer requires and never creates.

## Operations

### Self-test (no model)

```bash
bash ~/.claude/skills/pipeline-tools/scripts/selftest.sh
```

Exits 0 with `selftest: N passed, 0 failed`. Run it after editing any script and after a
Claude Code or git upgrade. It needs `bash`, `git`, and `awk`; it creates and removes a
temporary directory.

### Smoke test (with the agents)

1. Install the current `supervisor`, `worker`, and `worker-lite` agents and this skill
   (the `skill-version-check` skill does it), then start a new session.
2. `bash ~/.claude/skills/pipeline-tools/scripts/make-fixture.sh <empty dir>` and note the
   printed path.
3. In a session opened in that directory: "supervise phase 1 of smoke (artifacts-dir
   docs/, working branch smoke-run)", then "supervise phase 2 of smoke".
4. Check: the ledger's Phases 1 and 2 are complete; all four Steps rows are `done` with
   the cost columns filled; `git worktree list` shows only the main tree; no `wt/`
   branches remain; `git log --oneline` shows a merge and a record commit per step and a
   phase-complete commit per phase.
5. Parallelism: per phase, compare the sum of its two steps' `wall_s` with the phase's
   own duration (the supervisor's figure from the Agent tool). A ratio near 1.0 means the
   two foreground launches ran one after the other.

What it proves: the harness facts the agents rely on (nesting, foreground launches,
worktree handling, `omitClaudeMd`), the step-file parsers, and the supervisor's loop.
What it does not: decomposition quality (the steps are pre-written) and the planner.
Step 1b is `tier: lite`, so a run also shows whether `worker-lite` is dispatched.

### Lead-developer exercise (interactive, spends money)

The benchmarks never run the planner or the `lead-developer` skill. This fixture does,
on a two-milestone project whose synopsis is complete enough that the interview should
ask little or nothing.

1. `bash ~/.claude/skills/pipeline-tools/scripts/make-fixture.sh --fixture project <empty dir>`.
2. Open a session in that directory in auto mode (Sonnet at medium effort is enough for
   the driver; the pipeline agents pin their own models) and give the prompt the script
   printed: act as lead developer, plan from `SYNOPSIS.md` treating it as the complete
   interview input, then execute milestone by milestone.
3. Check on `develop`: the project ledger shows both milestones `done` with merge
   commits; `git log --oneline develop` shows `lead(notes): project plan`, two
   `milestone(notes): m<n> ...` squash commits, and `lead(notes): m<n> complete`
   commits; `git tag` lists `archive/notes-m1` and `archive/notes-m2`; no `milestone/`
   branches and no worktrees remain; and
   `bash ~/.claude/skills/pipeline-tools/scripts/dod-run.sh --file docs/notes-project-plan.md --heading "Definition of Done (project)"`
   prints `DOD PASS`.

What it proves beyond the benchmarks: the planner's plan operation (`dod` block
templates, `find-formatter-gates.sh`), the project-plan `dod` blocks, `dod-run.sh` at
Evaluate, the archive tag, and the `needs-amendment` relay if the decomposer raises one.
Expect roughly 5–8 USD at the adopted pins.

### Benchmark (headless, spends money)

`bench-run.sh` runs every phase of a fixture with `claude -p` from the fixture
directory, one configuration at a time, and appends a tab-separated row per run to
`bench-results.tsv`: timestamp, config, fixture, repeat, the overrides, phases completed,
project DoD verdict, `total_cost_usd` summed over phases, wall-clock, turns, the ledger's
Steps and cost columns summed, retries, revisions, leftover worktrees and branches, and
the per-model token and cost breakdown per phase. Each phase's raw JSON stays in
`bench/phase<N>.json` inside the fixture (kept with `--keep`).

Prerequisites: `claude` on PATH (v2.1.259 or later), the pipeline agents installed under
`~/.claude/agents`, this skill installed at `~/.claude/skills/pipeline-tools`, and a
budget. A smoke run costs cents; a `mid` run is dominated by the Opus decomposer and
supervisor. Every phase runs with `--max-budget-usd` (default 5) as a cap.

Configurations are expressed as overrides of one pipeline agent's frontmatter for that
run only; the copy lands in the fixture's `.claude/agents/`, which takes precedence over
`~/.claude/agents`, so the installed definitions are never touched:

```bash
S=~/.claude/skills/pipeline-tools/scripts
bash $S/bench-run.sh --config baseline --fixture smoke --repeat 3 --yes
bash $S/bench-run.sh --config baseline --fixture mid --repeat 2 --yes
bash $S/bench-run.sh --config x3-medium --fixture mid --repeat 2 --set decomposer.effort=medium --set supervisor.effort=medium --yes
bash $S/bench-run.sh --config x4-sonnet-sup --fixture mid --repeat 2 --set supervisor.model=sonnet --yes
bash $S/bench-run.sh --config x5-lite-on-sonnet --fixture smoke --repeat 3 --set worker-lite.model=sonnet --yes
bash $S/bench-summary.sh
```

`--dry-run` prints the plan and the exact `claude` command without running anything.
The `claude -p` session that spawns the supervisor runs on `haiku` by default
(`--driver-model`), so its cost is separable from the Sonnet workers' in the per-model
breakdown.

Decision rule (from the review): adopt a configuration only when, on every fixture, its
mean cost per completed run is below the baseline's and its DoD pass rate, mean retries,
and mean revisions are not worse than the baseline's beyond the noise floor — the spread
between repeated baseline runs. Two or three repeats per configuration per fixture. A
configuration that passes is applied by editing the agent's frontmatter pin (a minor
bump) and recording the benchmark rows in the commit message.

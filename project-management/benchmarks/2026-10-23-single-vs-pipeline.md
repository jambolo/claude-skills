# Pipeline versus single session — 2026-10-23

The review's X9 control, run headless with `bench-run.sh` (pipeline-tools 1.3.0) on
the `project` fixture: the `notes` tool, `SYNOPSIS.md` as the complete spec, every arm
judged by the same five checks in `fixture/project-dod.txt`. Pipeline arm: `--mode lead`
(lead-developer 3.0.2 on a Sonnet driver, driving planner 4.0.2, decomposer 4.1.0
opus/medium, supervisor 4.1.1 sonnet/high, worker 3.0.0, worker-lite 1.0.0). Control
arms: `--mode single`, one session with the Agent tool disallowed. Two runs each. Raw
rows: `2026-10-23-bench-results.tsv`. Costs are Claude Code's client-side estimates at
list price.

| config | mode | model / effort | runs | cost_usd (runs) | dur_s (runs) | dod | work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lead-sonnet | lead | Sonnet driver; pipeline pins | 2 | 3.90 (4.24, 3.56) | 1444 (1800, 1088) | 100% | 2 milestones; 5 and 6 steps |
| single-opus | single | Opus / default (medium) | 2 | 0.38 (0.45, 0.30) | 55 (66, 43) | 100% | 2 and 1 commits |
| single-sonnet | single | Sonnet / default (high) | 2 | 0.15 (0.17, 0.14) | 24 (18, 29) | 100% | 1 commit each |

## Reading

- **On a toy project the pipeline loses by an order of magnitude**: 10× the cost of a
  single Opus session and 26× that of a single Sonnet session, 26–60× the wall-clock,
  for the same five passing checks. The pipeline's cost is fixed overhead, about 1.95
  USD per milestone for the planner, decomposer, supervisor, and worker launches,
  regardless of how little work the milestone holds; the six scripts in `notes` are 24
  seconds of work for one Sonnet session.
- **Equal outcomes hide a difference in evidence.** The single session ran the checks
  itself and reported them. The pipeline left per-step reports, independent
  re-verification of every step, a ledger with cost columns, and archive tags. On work
  this small that evidence is worth nothing; on long work it is the difference between
  a verified result and a claimed one.
- **Choosing**: `/plan` (one session) for anything a single session finishes reliably in
  one go; `/lead-developer` for milestone-sized work that touches many files, benefits
  from parallel workers, or needs ground-truth verification. The break-even is not
  located by this fixture, which sits far below it.
- **The headless lead-developer run works**: with `--permission-prompts none` removing
  the question tool and the prompt telling it to choose the simplest option where the
  synopsis is silent, both runs planned, executed, and merged both milestones. The
  decomposer split milestone work into 5 steps in one run and 6 in the other.
- **Next**: measure the crossover on the `mid` fixture — a single session implementing
  the `textstat` brief and roadmap, judged by the brief's `dod` block, against the
  adopted pipeline's 1.64 USD and 605 s for the same plan (`bench-run.sh --mode single
  --fixture mid`, added in pipeline-tools 1.4.0).

## The `mid` crossover (same day, pipeline-tools 1.4.0)

A single session implementing the three-phase `textstat` brief and roadmap from the
`mid` fixture, judged by the brief's project `dod` block — the check the pipeline's own
`mid` rows were judged by. Two runs each.

| config | model / effort | runs | cost_usd (runs) | dur_s (runs) | dod | commits |
| --- | --- | --- | --- | --- | --- | --- |
| single-sonnet-mid | Sonnet / default (high) | 2 | 0.16 (0.155, 0.156) | 40 (41, 38) | 100% | 2, 2 |
| single-opus-mid | Opus / medium | 2 | 0.38 (0.387, 0.378) | 77 (79, 74) | 100% | 4, 4 |
| adopted pipeline (for reference) | decomposer opus/medium, supervisor sonnet/high | 2 | 1.64 (1.77, 1.52) | 605 (694, 516) | 100% | 8 steps, 3 phases |

- The crossover is not on `mid` either: one Sonnet session is 10× cheaper and 15×
  faster than the adopted pipeline for the same passing checks; one Opus session at
  medium effort is 4× cheaper and 8× faster. Both fixtures sit well below the
  pipeline's break-even.
- The pipeline's cost is fixed overhead: about 0.55 USD per phase on `mid` (decomposer,
  supervisor, launches) and about 1.95 USD per milestone on `notes` (planner
  included). The work inside the phases is cents of Sonnet time either way.
- The pipeline buys what these checks do not measure — independent re-verification of
  every step, isolation, a ledger and archive tags, parallel workers — and those matter
  only where one session fails: many-file changes, tasks long enough to exhaust or
  degrade one context, self-reported verification that cannot be trusted.
- Rule for choosing, as measured: default to `/plan` in one session (Sonnet first, Opus
  at medium when the task needs judgment); use `/lead-developer` for a milestone one
  session would not be trusted to finish and verify, at roughly 0.50 USD per phase plus
  1–2 USD per milestone for that assurance. Whether a real milestone crosses that line
  is the open question; the harness cannot answer it on synthetic fixtures of this
  size, so the next measurement is a real milestone: `/plan` plus `/cost` in one session
  against `/lead-developer` plus `/cost` in another, judged by the same `dod` checks.

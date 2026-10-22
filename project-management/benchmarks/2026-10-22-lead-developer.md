# Lead-developer exercise — 2026-10-22

First end-to-end run of the `lead-developer` skill and the planner since the batch-2
rewrite, on the `project` fixture (`make-fixture.sh --fixture project`: the two-milestone
`notes` tool, `SYNOPSIS.md` as complete interview input). Interactive session in auto
mode, Sonnet at medium effort as the driver; installed definitions lead-developer 3.0.2,
planner 4.0.2, decomposer 4.1.0 (opus/medium), supervisor 4.1.1 (sonnet/high), worker
3.0.0, worker-lite 1.0.0, pipeline-tools 1.2.0.

## Outcome: pass

Checked on `develop` after the run:

- Project ledger: both milestones `done` with merge commits 325b13e and 2cfc8ff, the
  archive tags in Notes, `current-milestone: done`, Events rows carrying each stage's
  tokens, tool uses, and duration, and a final `project DoD PASS 5/5` row.
- Tags `archive/notes-m1` and `archive/notes-m2`; no `milestone/` branches; only the
  main worktree; clean tree.
- Retained artifacts as the Merge step specifies: brief and ledger per milestone;
  roadmap, step files, and reports deleted on `develop` and reachable via the tags.
- `dod-run.sh` on `docs/notes-project-plan.md`: project 5/5, Milestone 1 3/3,
  Milestone 2 5/5. The project plan's `dod` blocks set `NOTES_FILE` inside each command.
- Interview: the project plan was committed 1.7 minutes after the initial commit. Whole
  run 31 minutes (21:20 to 21:51 local). No retries, revisions, amendments, or
  escalations.

## Per-stage figures (from the project ledger and the milestone ledgers)

| Stage | Milestone 1 (add-list) | Milestone 2 (search-docs) |
| --- | --- | --- |
| planner | 57,307 tokens, 22 tool uses, 313 s | 73,281 tokens, 29 tool uses, 427 s |
| decomposer | 44,056 tokens, 17 tool uses, 121 s | 55,959 tokens, 18 tool uses, 185 s |
| supervisor | 42,421 tokens, 19 tool uses, 117 s | 50,093 tokens, 19 tool uses, 536 s |
| steps | 1.1 lite 16,968 / 22 s; 1.2 lite 16,831 / 25 s; 1.3 standard 17,485 / 36 s | 01 lite 14,919 / 18 s; 02 lite 14,521 / 18 s; 03 standard 20,621 / 416 s |

Four of the six steps were `tier: lite` (verbatim content from the decomposer) and ran
on `worker-lite`; the two test-runner steps were `standard`. No dollar total: the session
was interactive, so no `total_cost_usd` was reported.

## Observations

- **Over-heavy acceptance on m2 step 03.** The decomposer's acceptance for the
  test-runner extension runs 15 mutant variants of the scripts and pins md5 sums of two
  regions of `test/run.sh`. It passed, but that check alone made the step 416 s (the
  worker's own run plus the supervisor's re-run) and the m2 supervisor 536 s against 117 s
  for m1. The decomposer's field notes already prefer anchored patterns and presence
  checks over exact counts; md5 pins and mutant batteries are stricter still and belong
  in the phase DoD, not a step's acceptance, when they are wanted at all.
- **Step id scheme is not pinned.** m1 used `1.1`, `1.2`, `1.3`; m2 used `01`, `02`,
  `03`. Both parse, and the fixtures use `1a`, `2b`. Cosmetic, but a fixed form
  (`<phase><letter>`) would make ledgers and commit messages uniform.
- **The planner is now the largest single stage per milestone** (313 s and 427 s, more
  tokens than decomposer or supervisor) and has no benchmark coverage: `bench-run.sh`
  runs plan fixtures only. A headless `project` run would need the lead developer to
  proceed without the interview, which this synopsis allowed; it is the natural next
  experiment if planner effort is to be tuned.
- The lead developer buffered the Events rows and wrote them at Merge, as specified, and
  set `current-phase: done` in both milestone ledgers.

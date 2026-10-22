# smoke — Ledger

Single source of truth for execution state. Sections are owned by different agents —
the planner seeds Plan + Phases; the decomposer fills Steps per phase; the supervisor
updates Steps and appends Revisions. This fixture ships with both phases already
decomposed.

## Plan
- plan-name: smoke
- current-phase: 1
- working-branch: smoke-run
- starting-commit: @STARTING_COMMIT@
- default-branch: none
- artifacts-dir: docs/

## Phases
| Phase | Status  | Notes |
|------:|---------|-------|
| 1     | pending |       |
| 2     | pending |       |

## Steps
| id | phase | status | files | commit | tokens | tool_uses | wall_s | retries |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1a | 1 | pending | src/greet.sh, docs/smoke-1a-report.md | | | | | |
| 1b | 1 | pending | src/count.sh, docs/smoke-1b-report.md | | | | | |
| 2a | 2 | pending | test/run.sh, docs/smoke-2a-report.md | | | | | |
| 2b | 2 | pending | README.md, docs/smoke-2b-report.md | | | | | |

Phase 1 notes: 1a and 1b have disjoint scopes and run in one wave.

Phase 2 notes: 2a depends on 1a and 1b; 2b depends on 1a. Both are ready once phase 1
is merged and run in one wave. No bootstrap is needed in fresh worktrees.

## Revisions

# textstat — Ledger

Single source of truth for execution state. Sections are owned by different agents —
the planner seeds Plan + Phases; the decomposer fills Steps per phase; the supervisor
updates Steps and appends Revisions. This fixture ships undecomposed: the supervisor
spawns the decomposer for each phase.

## Plan
- plan-name: textstat
- current-phase: 1
- working-branch: textstat-run
- starting-commit: @STARTING_COMMIT@
- default-branch: none
- artifacts-dir: docs/

## Phases
| Phase | Status  | Notes |
|------:|---------|-------|
| 1     | pending |       |
| 2     | pending |       |
| 3     | pending |       |

## Steps
| id | phase | status | files | commit | tokens | tool_uses | wall_s | retries |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## Revisions

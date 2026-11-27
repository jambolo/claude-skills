# Architectural Decision Records — `project-management` family

Decisions that shape the project-management pipeline, numbered in the order they were made (commit date of the commit that introduced the decision). The family is two skills (`lead-developer`, `pipeline-tools`) and five agents (`planner`, `decomposer`, `supervisor`, `worker`, `worker-lite`); the shared contract lives in `project-management/CLAUDE.md` and in the "Shared model" section the three stage agents duplicate.

| # | Title | Status | Date | Superseded by |
| --- | --- | --- | --- | --- |
| [0001](0001-three-stages-cooperate-only-through-markdown-artifacts.md) | Three stages (planner → decomposer → supervisor) cooperate only through Markdown artifacts keyed by `<plan-name>` | Accepted | 2026-07-04 | — |
| [0002](0002-supervisor-verifies-against-ground-truth.md) | The supervisor verifies every step against ground truth and never trusts a worker's report | Accepted | 2026-07-04 | — |
| [0003](0003-supervisor-creates-worktrees-at-an-exact-base.md) | All work lands on one local working branch, and the supervisor creates every worktree itself at an exact base | Accepted | 2026-07-04 | — |
| [0004](0004-plan-artifacts-are-committed-as-the-plan-proceeds.md) | Plan artifacts are committed on the working branch as the plan proceeds | Accepted | 2026-07-04 | — |
| [0005](0005-a-step-ends-in-one-commit-with-a-fixed-report.md) | A step ends in exactly one commit that includes a fixed-schema report; a worker reports an unsatisfiable check, it never games it | Accepted | 2026-07-22 | — |
| [0006](0006-acceptance-checks-are-dry-run-and-gate-steps-check-their-report.md) | The decomposer proves its acceptance checks; coupled steps declare a dependency; a gate step's acceptance targets its report | Accepted | 2026-07-22 | — |
| [0007](0007-brief-and-roadmap-stay-planner-owned-amendment-protocol.md) | The brief and roadmap stay planner-owned for the plan's whole life; defects travel as amendment notes | Accepted | 2026-07-27 | — |
| [0008](0008-ledger-rows-are-never-erased.md) | The ledger is a registry: a dropped step is marked `removed`, never erased, and each phase has a notes block | Accepted | 2026-07-27 | — |
| [0009](0009-lead-developer-drives-the-pipeline-per-milestone.md) | A `lead-developer` skill sits above the pipeline and runs it once per milestone, each on its own branch squash-merged into `develop` | Accepted | 2026-08-22 | — |
| [0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md) | The pipeline stages are agent definitions with pinned model, effort, and tools; only `lead-developer` is a skill | Accepted | 2026-08-23 | — |
| [0011](0011-artifacts-are-excluded-from-formatter-gates.md) | Pipeline artifacts are excluded from formatter gates, never formatted to pass them | Accepted | 2026-09-18 | — |
| [0012](0012-every-agent-launch-is-foreground.md) | Every agent launch passes `run_in_background: false` | Accepted | 2026-10-06 | — |
| [0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md) | The pipeline's deterministic mechanics are bash scripts in a `pipeline-tools` skill, and the artifact fields they read are a parsed schema | Accepted | 2026-10-22 | — |
| [0014](0014-lite-steps-go-to-a-haiku-worker.md) | Steps carry a `tier`; `lite` steps go to `worker-lite`, the same contract on Haiku | Accepted | 2026-10-22 | — |
| [0015](0015-a-small-phase-runs-inline-in-the-supervisor.md) | A phase the planner marks `inline` skips the decomposer and the workers; the supervisor does it in one commit | Accepted | 2026-11-26 | — |
| [0016](0016-the-ledger-registry-and-ready-set-are-scripted.md) | Registering steps, computing the ready set, and completing a phase are `pipeline-tools` scripts | Accepted | 2026-11-26 | — |
| [0017](0017-verify-and-record-in-one-call.md) | The supervisor verifies and records a step in one script call, and a PASS prints one line | Accepted | 2026-11-26 | — |
| [0018](0018-verbatim-content-is-applied-by-a-script.md) | Verbatim content travels in a step's `apply` block and is applied by `step-apply.sh`, never retyped | Accepted | 2026-11-26 | — |
| [0019](0019-the-decomposer-reads-one-phase-of-the-roadmap.md) | The decomposer reads its one phase of the roadmap through `phase-context.sh` | Accepted | 2026-11-26 | — |
| [0020](0020-the-planner-reads-no-other-plans-artifacts-and-reads-narrowly.md) | The planner reads no other plan's artifacts, and reads narrowly | Accepted | 2026-11-27 | — |

ADRs 0015–0020 come from the token-saving benchmark of 2026-11-26 and 2026-11-27. Its reports and run data were not kept; each ADR carries the figures that decided it.

## Measured and not adopted

Five further changes were built and benchmarked in the same programme and left out. Each has no ADR because it changed nothing.

| Change | Result | Why not |
| --- | --- | --- |
| A per-phase common file that steps name in a `common` field, read by the worker after its step file | Decomposer −7% (noise); supervision +4% and slower on the code phase | Steps shrink, but every worker reads about twice as much; an earlier 16% saving did not reproduce |
| A two-field worker report (`status`, `deviations`) | No measurable change in either round | The report is a few hundred tokens; [0005](0005-a-step-ends-in-one-commit-with-a-fixed-report.md) stands |
| Shorter `RESULT:` return messages from the decomposer and supervisor | Within noise in both rounds | The returns were already small |
| Phase-only material moved from the brief to a `### Phase <N> material` subsection of the roadmap | Planner −8% (noise); the bytes moved but the total did not | Every benchmark run planned one phase, so it was never tested on its target; see [0020](0020-the-planner-reads-no-other-plans-artifacts-and-reads-narrowly.md) |
| `plan-seed.sh`: check the brief and roadmap, seed the ledger, commit | Planner −9% (noise) | Seeding is a few turns at the end; the cost is in the reading before it |

## Reversed designs

No ADR is superseded, but several earlier designs were reversed by later commits and are recorded under "Alternatives considered" in the ADR that replaced them:

| Initial design | Commit | Replaced by |
| --- | --- | --- |
| Workers launched with the Agent tool's `isolation: "worktree"` | e3ff846 | [0003](0003-supervisor-creates-worktrees-at-an-exact-base.md) (106acf1) |
| Plan artifacts written to disk and left uncommitted | e3ff846 | [0004](0004-plan-artifacts-are-committed-as-the-plan-proceeds.md) (106acf1) |
| Worker commits, then writes a report naming its own commit SHA | 106acf1 | [0005](0005-a-step-ends-in-one-commit-with-a-fixed-report.md) (61ac934) |
| Gate step checks "project state only" with no rule for its own acceptance | 61ac934 | [0006](0006-acceptance-checks-are-dry-run-and-gate-steps-check-their-report.md) (a9be4d0) |
| A dropped step's ledger row is deleted | implicit until fbc90c0 | [0008](0008-ledger-rows-are-never-erased.md) (fbc90c0) |
| Stages are skills loaded in a general-purpose subagent; caller passes model and effort; worker contract pasted into each launch | e3ff846, 0719e9c | [0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md) (5cde06f) |
| Versioned model ids in frontmatter (`claude-fable-5`) | 5cde06f | [0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md) (68ecbaa) |
| The decomposer spawns the planner for an amendment | 5cde06f | [0007](0007-brief-and-roadmap-stay-planner-owned-amendment-protocol.md) (5039ccd: returns `needs-amendment`) |
| One ignore glob for every formatter tool | af9f8fd | [0011](0011-artifacts-are-excluded-from-formatter-gates.md) (3a67c8b) |
| "Foreground" stated in prose, no parameter passed | 5cde06f | [0012](0012-every-agent-launch-is-foreground.md) (ab8453e) |
| The supervisor composes git commands for worktrees, verification, and merges | e3ff846, 106acf1 | [0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md) (5039ccd) |
| One Sonnet worker for every step; `effort: low` | 14d3312, 5cde06f | [0014](0014-lite-steps-go-to-a-haiku-worker.md) (3a67c8b, 5039ccd) |
| Every phase is decomposed, however small | e3ff846 | [0015](0015-a-small-phase-runs-inline-in-the-supervisor.md) (c48f7d3) |
| The decomposer hand-writes Steps rows and the dependency graph; the supervisor derives the ready set and edits the ledger to complete a phase | fbc90c0, 5039ccd | [0016](0016-the-ledger-registry-and-ready-set-are-scripted.md) (7eb8eaf, e79193f, ecb60b2) |
| `step-verify.sh` and `step-merge.sh` are two calls, with full evidence on a PASS | 5039ccd | [0017](0017-verify-and-record-in-one-call.md) (175539b) |
| Verbatim content sits in `actions` and the worker types it | 5039ccd | [0018](0018-verbatim-content-is-applied-by-a-script.md) (60e3661) |
| The decomposer reads the whole roadmap | e3ff846 | [0019](0019-the-decomposer-reads-one-phase-of-the-roadmap.md) (55540ad) |
| The planner opens the previous milestone's brief as a model for the new one | implicit until bd8ab91 | [0020](0020-the-planner-reads-no-other-plans-artifacts-and-reads-narrowly.md) (bd8ab91) |

## Commit key

| SHA | Date | Subject |
| --- | --- | --- |
| e3ff846 | 2026-07-04 | Reorganized the collection. Added project management skills |
| 106acf1 | 2026-07-04 | Project management skills now commit plan artifacts as the plan proceeds. Fixed a problem where a worker's worktree was based on the wrong commit. |
| 46b8e7a | 2026-07-22 | Added post-mortem of the game-player mcts-value-estimator pipeline run |
| 61ac934 | 2026-07-22 | Applied post-mortem recommendations R1-R12 to the project-management skills |
| a9be4d0 | 2026-07-26 | Clarified the purpose of the final gate step in a phase. |
| fbc90c0 | 2026-07-27 | Applied two-player-game run review findings to project-management skills |
| 14d3312 | 2026-08-21 | supervisor: Specifies that workers use "effort: low" for mechanical routes. |
| 0719e9c | 2026-08-22 | Added `lead-developer` skill. |
| a3a7d2f | 2026-08-22 | Renamed some poorly named skill operations. |
| 5cde06f | 2026-08-23 | project-management: Converted planner and supervisor skills to agents. Created a worker agent. Pinned model/effort in the agent front matter. |
| 68ecbaa | 2026-09-17 | project-management: Removed version specifiers from model ids in agent front matter |
| bc9f869 | 2026-09-17 | project management: Ran claude-api prompt-audit on skills |
| af9f8fd | 2026-09-18 | project management: Agents now prevent any formatter from running on artifact files. |
| 428dcd8 | 2026-09-24 | project-management: downgraded the models for decomposer and planner to opus. |
| ab8453e | 2026-10-06 | project-management: Every agent launch now passes run_in_background: false |
| 3a67c8b | 2026-10-16 | Address 2026-10-16 ultrareview findings; misc skill updates |
| 6bed64e | 2026-10-22 | project-management: add 2026-10-22 pipeline review |
| 5039ccd | 2026-10-22 | project-management: applied pipeline review recommendations |
| bd0864d | 2026-10-22 | project-management: Comparison with /plan |
| 55540ad | 2026-11-26 | `feature/pipeline-phase-context`: `phase-context.sh` |
| 7eb8eaf, e79193f, ecb60b2 | 2026-11-26 | `feature/pipeline-steps-register`: `steps-register.sh`, `phase-ready.sh`, `phase-complete.sh` |
| c48f7d3 | 2026-11-26 | `feature/pipeline-inline-phases`: inline phases |
| 60e3661 | 2026-11-26 | `feature/pipeline-step-apply`: `step-apply.sh` and the `apply` block |
| 175539b | 2026-11-26 | `feature/pipeline-verify-merge`: `step-verify.sh --quiet --merge-on-pass` |
| bd8ab91 | 2026-11-27 | planner: other plans' artifacts are not input (no read of an earlier milestone's brief) |
| 98cedf7 | 2026-11-27 | planner: read narrowly (sections and line ranges, nothing twice) |

The two run reviews that drove 61ac934 and fbc90c0 were removed from the tree in 3a67c8b; they are reachable at `git show 46b8e7a:project-management/game-player-mcts-value-estimator-post-mortem.md` and `git show fbc90c0:project-management/four-in-a-row-two-player-game-review.md`.

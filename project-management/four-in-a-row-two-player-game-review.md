# Review — two-player-game pipeline run (four-in-a-row)

Review of the planner → decomposer → supervisor artifacts for the `two-player-game` plan
(`C:\Users\John\Projects\four-in-a-row\docs\two-player-game-*.md`, 38 files, all 4 phases
complete, brief DoD items 1–6 PASS). Goal: find improvements to the project-management
skills based on what the run actually exposed.

Overall: the pipeline ran clean — one revision (naming grep), zero merge conflicts, scope
checks held, no report self-SHA violations. The findings below are places the run only
succeeded because a strong supervisor improvised, plus schema/convention drift.

## Planner findings

### 1. Project DoD gate broke on the pipeline's own artifacts

Brief DoD item 5 (naming grep) was unsatisfiable verbatim: the plan artifacts in `docs/`
quote the forbidden trademarked name, so the grep matched them. This forced a mid-run,
user-approved pathspec deviation (`':!docs/two-player-game-*.md'`), documented in the
ledger phase-4 notes and gate step 4e.

**Recommendation:** add a planner pitfall — dry-run grep-style project DoD gates against
the *end-state* repo, which contains `<artifacts-dir>/<plan-name>-*.md`. Either exclude
the plan artifacts from such gates at planning time or place artifacts outside the
shipped tree.

**Decision:** ignore — the situation is unique to this specific project.

### 2. No artifact end-of-life policy

The ledger says the plan artifacts are "scheduled for removal from git history" — a
history rewrite, decided ad hoc mid-run.

**Recommendation:** add a Plan-section field, e.g.
`artifact-disposal: keep | strip-at-end | separate-branch`, set by the planner up front.

**Decision:** won't fix — not important enough.

### 3. Human-only DoD items have no protocol

DoD item 6 (human smoke test via `pnpm tauri dev`) was handled ad hoc: gate 4e recorded
`human-check: PENDING` with the checklist, the user ran it later, the supervisor
committed "record phase 4 human smoke test PASS", and the ledger note explicitly states
it "supersedes that report's PENDING marker". Every piece was improvised — the skills
define none of it.

**Recommendation:** formalize — the planner tags human-only DoD items; the supervisor's
phase-DoD step collects PENDING human checks, presents them to the user, and records the
outcome in the ledger. Reports stay immutable; the ledger supersedes.

**Decision:** won't fix — not important enough.

### 4. Undefined ledger terminal value

The ledger ended with `current-phase: complete (…)`. The schema only defines phase
numbers.

**Recommendation:** define `complete` as the terminal value for `current-phase`.

**Decision:** won't fix — not important enough.

## Decomposer findings

### 5. Unexplained step-id gap

Phase 4 steps are 4a, 4b, 4c, 4e — no 4d anywhere in the artifacts or git history, and
no Revisions row. Cause: the supervisor recognized during decomposition that the planned
4d step was superfluous, and it was dropped without a trace. The gap looks like a lost
or superseded step and cost an audit detour.

**Recommendation (as decided):** never erase a step. A step judged superfluous is
registered (or kept) in the ledger's Steps table with `status: removed` — by the
decomposer or the supervisor, whichever recognizes it — with the reason recorded in the
phase notes. Every id in a phase stays accounted for.

**Decision:** fix as above — applied to the decomposer and supervisor skills.

### 6. Revised constraints never flow back into the brief

Revision 1 widened the naming grep to inflected forms
(`connect(ed|s|ing)? ?-?(4|four)`). The fix propagated only via per-phase ledger notes
("per the Phase 1 revision note") — the brief, which is the projection source for all
later phases, still holds the weak grep. Nobody is authorized to amend the brief
post-planning; a decomposer run that missed the ledger note would regress.

**Recommendation:** add a **brief amendment loop**, mirroring the revision loop
(supervisor → decomposer). The discoverer never edits the brief itself — that would
break the pipeline's layering rule (every stage reports defects upward to the artifact's
owner; it never repairs the artifact — same reason a worker never fixes its own step).
All brief amendments go through the planner, with no fast-path exception for
"mechanical" fixes — misclassifying a fact as ripple-free is exactly the failure mode.

Process:

1. The discoverer (decomposer or supervisor) writes an **amendment note**, structured
   like the supervisor's revision note:

   ```markdown
   - trigger: <phase/step where the defect surfaced>
   - defect: <what in the brief is wrong/unsatisfiable, quoted exactly>
   - observed: <what actually happened>
   - root cause: <why the brief text is defective>
   - suggested amendment: <proposed replacement text>
   - blast radius: <sections/phases the discoverer THINKS are affected — a lead, not a verdict>
   ```

2. The discoverer invokes the **planner via the Skill tool** with the note. The planner
   gains an **Operation B — amend** (it currently has only plan-a-goal), symmetric with
   the decomposer's Operation B — revise.

3. The **planner owns the edit**: it re-reads brief + roadmap + ledger at altitude and
   checks **ripple** — a constraint change may touch multiple brief sections, the
   project DoD, *and* roadmap phase DoDs (the roadmap is also planner-owned; an
   amendment may need both files). It applies a strengthen/weaken rule: gate
   *strengthening* (e.g. widening the naming grep) is self-serve; gate *weakening* or
   scope/DoD changes require explicit user approval (the DoD item 5 pathspec deviation
   was correctly user-approved). It edits the brief **in place** — never an appendix,
   never ledger notes; a fix living anywhere but the projection source depends on every
   future reader remembering to look there. It appends a Revisions row and commits
   `amend(<plan-name>): brief — <what>` before returning.

4. Control returns to the discoverer stage. The amendment must be committed before the
   next decomposition that depends on it; already-emitted pending steps embedding the
   stale text go through the normal decomposer revision. Completed steps stay untouched —
   the Revisions row records that they ran against the old text.

Ownership table stays clean: brief/roadmap written by **planner (seed + amendments)**;
no third writer appears. Skill changes: shared-model section gains the amendment
protocol (all three, kept in sync); planner gains Operation B — amend; supervisor's
Decide options gain "(e) Amend brief" alongside revise/escalate.

Applied to this run: the phase-1 "connected four" graze → supervisor writes an
amendment note → planner widens the brief's grep to `connect(ed|s|ing)? ?-?(4|four)`
(strengthening, self-serve), updates DoD item 5, commits — phases 2–4 decompose from a
correct brief, no per-phase note relay.

**Decision:** adopted — all brief amendments go through the planner, no fast path for
"mechanical" fixes. Applied to all three skills: shared-model "Brief amendment
protocol" section (duplicated, kept in sync), planner Operation B — amend, supervisor
Decide option (e) + phase-DoD clause + pitfall, decomposer orientation paragraph +
pitfall.

### 7. Ledger phase-notes are load-bearing but unschema'd

The decomposer added "Phase N dependency graph" and "Phase N notes for workers/
supervisor" sections to the ledger. These carried critical facts: the
pnpm-build-before-cargo ordering, the pinned Phase 3 DOM contract, the emergent
`GameState`/`Cell`/`PlayerId` type names Phase 3 renders from, greet-removal sequencing.
None of this is in the ledger schema.

**Recommendation:** add a decomposer-owned per-phase notes section to the ledger schema.
Also rename it — workers never see the ledger (they see only their step file), so "notes
for workers" misleads; the notes serve the supervisor and future decomposer runs, and
their content must still be projected into step files.

**Decision:** fix as described — applied to the decomposer and planner skills.

### 8. `files_in_scope` formatting drift

Step 4e's `files_in_scope` entry is backticked (`` `docs/…` ``); every other step uses
plain paths. A naive subset check against `git diff --name-only` breaks on the
formatting.

**Recommendation:** schema note — `files_in_scope` entries are plain paths, no markdown
formatting.

**Decision:** fix as described — applied to the decomposer skill.

## Supervisor findings

### 9. Commit-message anarchy

Work-commit messages across the run: `step(3a):`, `Step 2a:`, `4b:`, `docs(4c):`,
`feat(3b)`, and worst — `decompose(two-player-game): step 3c` on a **work** commit
(`79e2fd1`, verified: it contains `src/main.ts` + tests, not decomposition output). That
message mislabels the step's actual work as a decomposer artifact and actively misleads
audit. Merge messages drift too: `merge step 3b (two-player-game phase 3)` vs
`merge(two-player-game): step 4a …`. The worker contract only says "message naming the
step id".

**Recommendation:** pin exact formats in the worker contract and merge mechanics:

- work commit: `step(<plan-name>/<id>): <summary>`
- merge commit: `merge(<plan-name>): step <id>`
- supervisor commits: `supervise(<plan-name>): <what>`

**Decision:** fix as described — applied to the supervisor skill.

## What worked — keep as is

- Gate-step design: honest-FAIL semantics, acceptance targeting the report rather than
  project state (1f, 2c, 3d, 4e all clean).
- Missing-base assertions as the first action of every dependent step.
- "Check the check": the supervisor caught the `Status::Won` doc comment "has connected
  four and won" — which passed the pinned grep — reworded it in an integration commit,
  and recorded a Revisions row. Exactly per skill.
- Verbatim-code embedding used only where a plausible variant would be silently wrong
  (step 1a's `DIRECTIONS`/`run_len`/`drop_disc`/`winning_cells`), per the
  specification-level guidance.
- Lone-step in-tree execution (2c, 3c, 3d, 4e) with the clean-status precondition.
- Cost note, no change recommended: each phase DoD runs twice (gate worker + supervisor
  re-run). Inherent to the never-trust discipline and worth the price.

## Decisions summary

| Finding | Decision |
| --- | --- |
| 1 | Ignore — unique to this project |
| 2–4 | Won't fix — not important enough |
| 5 | Fix (revised): mark superfluous steps `removed` in the ledger, never erase |
| 6 | Adopted: all brief amendments go through the planner — applied to all three skills |
| 7 | Fix as described — decomposer + planner |
| 8 | Fix as described — decomposer |
| 9 | Fix as described — supervisor |

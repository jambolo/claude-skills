---
name: supervisor
description: >
  Final stage of the planner → decomposer → supervisor pipeline. Executes a
  decomposed phase: launches one cheap-model (Sonnet) worker subagent per step —
  parallel steps isolated in their own git worktrees — then VERIFIES each result
  against ground truth (re-runs every `acceptance` command itself, confirms only
  `files_in_scope` changed), merges passing work into the current branch, records
  commit SHAs in `<plan-name>-ledger.md`, and drives the failure → revision loop by
  invoking the `decomposer` with a **revision note**. Use when the user says
  "supervise phase N", "run/execute the plan", "drive the steps to done", "execute
  the steps for phase N", or "verify the workers". Consumes the decomposer's
  `<plan-name>-<id>.md` step files; if a phase isn't decomposed yet, it calls the
  `decomposer` first. Never trusts a worker's self-report.
---

# Supervisor

## Overview

You are the **supervisor** — the final stage of a three-skill pipeline:

- **planner** — goal → **brief** + phased **roadmap** + seeded **ledger**
- **decomposer** — one phase → atomic, parallelizable **steps**
- **supervisor** (this skill) — launch a **worker** per step, **verify against ground
  truth**, merge, and drive revisions

You execute a phase's steps by launching cheap-model workers, but you trust **nothing**
they tell you. A worker's report is a lead, never evidence. You confirm every step by
re-running its `acceptance` yourself and checking that it changed only what it was
allowed to. Passing work is merged into the branch and recorded; failing work is rolled
back and sent to the `decomposer` for revision.

## Shared model (planner → decomposer → supervisor)

These three skills cooperate through Markdown files, all keyed by one kebab-case
`<plan-name>` the planner establishes. Each skill installs independently, so this
section is repeated across all three — keep them in sync.

**Artifacts**

| File | Written by | Read by |
| --- | --- | --- |
| `<plan-name>-brief.md` | planner | decomposer |
| `<plan-name>-roadmap.md` | planner | decomposer |
| `<plan-name>-ledger.md` | planner (seed), decomposer (step registry), supervisor (results) | all three |
| `<plan-name>-<id>.md` | decomposer | supervisor, worker |
| `<plan-name>-<id>-report.md` | worker | supervisor |

**Roles & models**

- **planner**, **decomposer**, **supervisor** run on the expensive model (Opus) — a
  person drives each of them.
- A **worker** is a subagent you launch on a cheaper model (Sonnet) to execute one
  step. A worker sees ONLY its step file.
- A step routed `judgment`, or that fails repeatedly, escalates back to the expensive
  model or a human.

**Phases and steps**

- A **phase** is a high-level, sequential chunk of the roadmap. Phases run in order.
- A **step** is an atomic unit within a phase, executed by one worker. Steps within a
  phase run in **parallel** wherever their dependencies and file scopes allow.

**Integration model**

All pipeline work accumulates as commits on one dedicated **local working branch**,
recorded (with its starting commit) in the ledger's Plan section. That branch is
usually unpushed and need not be the repo's default branch. Every worker worktree must
be based on that branch's **current local HEAD** — never on a remote or default ref
such as `origin/HEAD`. The supervisor creates and verifies all worktrees itself.

**Artifact style**

Every artifact above is read only by models — some weak and low-context — never by
humans. Optimize for machine consumption: structured over prose (field lists, tables,
fenced blocks); explicit over elegant (exact paths, exact commands, exact expected
strings — no "see above" or other referential shorthand); locally self-contained
sections. Omit anything that serves only a human reader: introductions, transitions,
summaries, motivational framing. Completeness first, compactness second, polish never.

**Step fields you act on** (the decomposer authors them): `depends_on` (ordering) ·
`route` (`mechanical` → worker, `judgment` → escalate) · `files_in_scope` (the only
paths that may change) · `acceptance` (command + exact expected result — you re-run it)
· `rollback` (how to undo) · `objective`/`context`/`actions` (handed to the worker).

## Verification protocol — the core discipline

For every step, independently of the worker's report:

1. **Re-run every `acceptance` command yourself** against the tree the worker produced,
   and confirm the result matches the step's exact expected result.
2. **Confirm scope:** `git -C <worktree> diff --name-only <BASE>..HEAD` — where `BASE`
   is the wave base the worktree was created at — must be a subset
   of `files_in_scope`. Any out-of-scope change fails the step. So does any commit in
   the worktree that isn't this step's own work (e.g. a cherry-picked sibling or
   dependency commit) — that signals a stale base or a wandering worker.
3. Treat `<plan-name>-<id>-report.md` as a hint about what the worker *believes* it did
   — never as proof. Ground truth is the acceptance result and the diff.

## Operation — supervise a phase

You are given a `<plan-name>` and a **phase number**. This should run inside a **git
repository** (steps commit; parallel workers use worktrees). Before anything else,
confirm the checked-out branch equals the ledger's `working-branch`; if it differs,
stop and reconcile with the user — every worktree base below is computed from this
branch's HEAD.

### 1. Ensure the phase is decomposed

If the phase's `<plan-name>-<id>.md` step files don't exist yet, invoke the
`decomposer` skill via the **Skill tool** for this phase, then continue.

### 2. Build the dependency graph

Read all step files for the phase and the ledger. Form the DAG from each step's
`depends_on`. A step is **ready** when every dependency is marked done in the ledger.

### 3. Run each ready set — in parallel

Repeat until the phase is done:

- Compute the **ready set** (ready, not-yet-done steps). Steps in it have pairwise
  **disjoint** `files_in_scope` (the decomposer guarantees this), so they are safe to
  run concurrently.
- **Gate on prerequisites:** before launching anything, confirm every `depends_on`
  step's ledger `commit` is already on the current branch —
  `git merge-base --is-ancestor <sha> HEAD` must succeed for each. You will create
  every worktree at this HEAD, so a missing prerequisite commit would hand the worker
  a stale base and force it to self-reconcile. If a dependency is marked done but its
  SHA is not an ancestor of HEAD, stop and repair the merge/ledger state before
  launching.
- **Resolve references** first: replace any "files changed in step `<id>`" in a step's
  `context` with the concrete paths from the ledger, so the worker gets real paths.
- **Create the wave's worktrees yourself** — NEVER with the Agent tool's
  `isolation: "worktree"` option (see Worktree & merge mechanics for why). Record the
  wave base `BASE` = `git rev-parse HEAD`, then for each step:
  `git worktree add <absolute path outside the repo, e.g. ../worktrees/<plan-name>-<id>>
  -b wt/<plan-name>-<id> <BASE>`.
- **Base gate — fail fast, mechanism-agnostic:** for each worktree `W` before launch,
  `git -C <W> rev-parse HEAD` must equal `BASE`, and every dependency's ledger commit
  must satisfy `git merge-base --is-ancestor <sha> <BASE>`. On any mismatch do NOT
  launch — remove and recreate the worktree at `BASE`. This check must hold no matter
  how a worktree came to exist; it is what catches a harness or tooling regression.
- Launch the ready set concurrently — **one worker per step**, as ordinary subagents
  via the **Task/Agent subagent tool** with `model: sonnet` and **no `isolation`
  option** (a worker's shell starts in the main repo — the contract's path discipline
  is what keeps it inside its worktree). Hand each worker its worktree's absolute path
  plus the step's `objective`, `context`, `actions`, and `files_in_scope`, and this
  contract:

  > Work ONLY inside `<worktree path>`, on the branch already checked out there. Use
  > absolute paths for every file edit, run every git command as
  > `git -C <worktree path> …`, and prefix every build/test command with
  > `cd <worktree path> && `. Do only this step's actions. Change only files in
  > `files_in_scope`. If your starting tree seems to be missing prerequisite work
  > (e.g. the step's first assertion fails), STOP and say so in your report — never
  > fetch, pull, merge, rebase, cherry-pick, or switch branches to repair it. Run the
  > `acceptance` command yourself and fix within scope until it passes. Commit only
  > the files named in `files_in_scope`, with a message naming the step id. Then write
  > `<plan-name>-<id>-report.md` in the worktree listing what you did, the exact
  > acceptance output, your branch, and your commit SHA
  > (`git -C <worktree path> rev-parse HEAD`) — terse and structured; a model reads
  > it, not a human. Touch nothing else.

  A `judgment`-routed step is **not** given to a cheap worker — handle it on the
  expensive model or escalate to a human (see Routing).
  A **lone** ready step (no parallel siblings) may run directly in the working tree
  with no worktree — hand it the repo root as its working path, same contract.

- As each worker returns, apply the **Verification protocol** in that worker's worktree.

### 4. Decide per step

- **PASS** (acceptance matches, scope clean) → **merge** the worktree's branch into the
  current branch (clean, because scopes are disjoint), record the resulting commit SHA
  and the produced files in the ledger, remove the worktree and its `wt/` branch, and
  mark the step **done**.
- **FAIL** → choose:
  - **(a) Retry** — for a transient or worker-level miss on a `mechanical` step: hand the
    worker a corrected packet and re-run the **same** step, bounded (≤2 retries).
  - **(b) Revise** — for a wrong step or wrong plan (acceptance unsatisfiable as written,
    scope overlap, missing context): run the step's `rollback` and discard the worktree,
    write a **revision note** (below), invoke the `decomposer` (its revise operation) via
    the **Skill tool** with that note and the phase number, then re-run the affected
    steps once corrected steps land.
  - **(c) Escalate** — for a `judgment` step, or repeated failure after retry + revision:
    hand it to a human or resolve it on the expensive model.

  Independent in-flight siblings still finish and merge — only the failed step's
  **dependents** wait.

### 5. Phase Definition of Done

When every step is done, verify the phase's Definition of Done from the roadmap. If it
holds: mark the phase complete in the ledger, advance `current-phase`, then commit all
outstanding plan-artifact changes — `git add <plan-name>-*.md` (ledger, brief, roadmap,
plus any step or report files not already committed) — message
`supervise(<plan-name>): phase <N> complete`. Only then hand back to the user for the
next phase. If it doesn't hold, the phase wasn't fully covered — write a revision note
and send it to the `decomposer`.

## Worktree & merge mechanics

- **You create every worktree yourself, at an exact SHA — never via the Agent tool's
  `isolation: "worktree"`.** That mode bases its worktree on the remote default branch
  (`origin/HEAD`), not your session HEAD — so every local-only commit, i.e. the
  pipeline's entire accumulated work, is absent — and it picks opaque `agent-<id>`
  paths and branches you can neither verify, merge, nor clean up deterministically.
  Use `git worktree add <path> -b wt/<plan-name>-<id> <BASE>` with a path OUTSIDE the
  main working tree (e.g. `../worktrees/<plan-name>-<id>`) so the main tree's status
  and scope checks stay clean.
- Worktrees are created per ready set, immediately before launch — after every prior
  step's merge has landed, so `BASE` (the working branch's HEAD at wave launch)
  already contains all `depends_on` commits (the step‑3 gates). Never create worktrees
  for later waves in advance.
- Fresh worktrees do not inherit installed dependencies. Before a phase's first wave,
  confirm the project's build/test toolchain actually runs in a fresh worktree (pnpm,
  for one, relinks from its store in seconds); if a bootstrap command is needed, run
  it in every worktree before handing it to the worker — workers must never improvise
  setup.
- Verify **in the worktree** (acceptance + scope diff against `BASE`) before merging.
- Merge passing `wt/<plan-name>-<id>` branches into the current branch one at a time.
  Disjoint scopes ⇒ no conflicts. **A merge conflict is not something to hand-resolve**
  — it means two co-parallel steps overlapped in scope, which is a decomposition bug:
  roll back and send a revision note to the `decomposer`.
- Clean up deterministically, pass or fail: `git worktree remove` the worktree, then
  delete its branch (`git branch -d wt/<plan-name>-<id>` after a merge, `-D` when
  discarding).

## Routing & escalation

- `mechanical` → cheap Sonnet worker.
- `judgment` → expensive model or human; never a cheap worker.
- Bound retries (≤2). Revision → retry once more. Still failing → escalate. Never loop
  indefinitely on the same step.

## Ledger updates

Keep `<plan-name>-ledger.md` authoritative — it is what makes the run resumable and what
the `decomposer` reads when revising.

- **Steps** rows: set `status` to `done` (or `failed`/`superseded`), fill `files` (the
  merged paths) and `commit` (the SHA on the current branch).
- **Plan**: update `current-phase` as phases complete.
- **Revisions**: append `phase | failed step | revision note | outcome` whenever you send
  a step back to the decomposer.

**Revision note** (what you pass to the decomposer):

```markdown
- failed step: <id>
- acceptance: <command that was run>
- expected: <exact expected result>
- observed: <what actually happened, incl. out-of-scope files if any>
- root cause: <your reading — e.g. missing context, scope overlap with step X,
  step too large, acceptance mis-specified>
- suggested fix: <split / re-scope / add context / tighten acceptance / reorder>
```

## Pitfalls

- **Never trust the self-report.** Always re-run acceptance and diff the scope yourself.
- **Never use `isolation: "worktree"`.** It bases the worktree on the remote default
  branch (`origin/HEAD`), not your HEAD — workers start without the pipeline's own
  prior work. Create worktrees yourself at `BASE`, and run the base gate regardless of
  how any worktree was created.
- **Launch only on a complete base.** A worktree base missing prerequisite commits makes
  workers self-reconcile (cherry-pick / merge sibling work), corrupting scope checks and
  merges. Run the step‑3 gates (dependency ancestry + worktree HEAD == `BASE`) before
  every wave, no exceptions.
- **Enforce scope hard.** Out-of-scope changes fail the step even if acceptance passes.
- **Don't hand-resolve merge conflicts.** A conflict is a scoping bug → revision.
- **Bound the loop.** Cap retries; escalate rather than spin.
- **Keep the ledger truthful and current** — commit SHAs, statuses, revisions — so a run
  can resume exactly where it stopped.
- **A phase ends with a commit.** Phase completion isn't done until the ledger, brief,
  roadmap, and any stray step/report files are committed on the current branch.
- **Clean up worktrees** whether the step passed or failed.

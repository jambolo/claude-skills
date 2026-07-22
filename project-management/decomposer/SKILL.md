---
name: decomposer
description: >
  Middle stage of the planner → decomposer → supervisor pipeline. Decomposes ONE
  phase of a plan (from the planner's `<plan-name>-brief.md` and
  `<plan-name>-roadmap.md`) into atomic, parallelizable **step** files
  `<plan-name>-<id>.md`, each self-contained enough for a low-context, cheap-model
  worker that sees only that one file. Projects the slice of the brief and roadmap
  each step needs into its `context`, wires `depends_on`, keeps parallel steps' file
  scopes disjoint, and gives every step a concrete `acceptance` command with an exact
  expected result. Use when the user says "decompose phase N", "break this phase into
  steps", "generate the steps for phase N", or when the `supervisor` invokes this
  skill with a **revision note** to fix a failed or mis-planned step. Requires the
  planner's artifacts to exist. This skill does not execute steps — that is
  `supervisor`.
---

# Decomposer

## Overview

You are the **decomposer** — the middle stage of a three-skill pipeline:

- **planner** — goal → **brief** + phased **roadmap** + seeded **ledger**
- **decomposer** (this skill) — one phase → atomic, parallelizable **steps**
- **supervisor** — launches a **worker** per step, verifies, merges, drives revisions

You break one phase into **steps**, one file each, sized for a weak, low-context worker.
The defining constraint: **the worker sees ONLY its step file** — none of the brief,
roadmap, or sibling steps. So you must **project** whatever it needs into each step's
self-contained `context`. Anything you leave out does not exist for the worker.

## Shared model (planner → decomposer → supervisor)

The three skills cooperate only through Markdown files keyed by one kebab-case
`<plan-name>` the planner establishes. Each installs independently, so this section is
duplicated across all three — keep them in sync.

**Artifacts**

| File | Written by | Read by |
| --- | --- | --- |
| `<plan-name>-brief.md` | planner | decomposer |
| `<plan-name>-roadmap.md` | planner | decomposer |
| `<plan-name>-ledger.md` | planner (seed), decomposer (step registry), supervisor (results) | all three |
| `<plan-name>-<id>.md` | decomposer | supervisor, worker |
| `<plan-name>-<id>-report.md` | worker | supervisor |

Every one of these files lives in a single directory recorded as `artifacts-dir` in the
ledger's Plan section — the planner sets it (`docs/` is conventional); the decomposer and
supervisor resolve artifact paths from it rather than guessing.

**Roles & models**

- **planner**, **decomposer**, **supervisor** run on the expensive model (Opus), each
  driven by a person.
- A **worker** is a subagent the supervisor launches on the cheap model (Sonnet) for one
  step. It sees ONLY its step file — none of the brief, roadmap, or sibling steps.
- A step routed `judgment` (no clean deterministic answer), or one that fails repeatedly,
  escalates to the expensive model or a human.

**Phases and steps**

- A **phase** is a sequential chunk of the roadmap; phases run in order, a later one
  assuming earlier ones are done.
- A **step** is an atomic unit within a phase, run by one worker. Co-phase steps run in
  **parallel** wherever dependencies and file scopes allow.

**Integration model**

All work accumulates as commits on one dedicated **local working branch** (its starting
commit is in the ledger's Plan section) — usually unpushed, not necessarily the repo
default. Every worker worktree bases on that branch's **current local HEAD**, never a
remote or default ref like `origin/HEAD`. The supervisor creates and verifies all
worktrees itself.

**Artifact style**

Only models read these artifacts — some weak, low-context — never humans. Write for
machine consumption: structured over prose (fields, tables, fenced blocks); explicit over
elegant (exact paths, commands, expected strings — no "see above"); self-contained
sections. Cut anything only a human needs — intros, transitions, summaries. Completeness
first, compactness second, polish never.

**Worker report & commit protocol**

A step ends in exactly ONE commit containing every changed `files_in_scope` path — the
report included, so the worker writes `<plan-name>-<id>-report.md` BEFORE committing. Report
fields: `status: pass | fail | missing-base` · `base` (the SHA the work started from) ·
`changes` (what was actually done) · `acceptance` (each command with its verbatim output) ·
`deviations` (anything done other than as instructed, else "none"). A report never contains
its own commit SHA, branch, or anything else self-referential — the supervisor reads commit
identity from git, and a SHA recorded inside the commit it names cannot be written.

## The step schema

Emit one `<plan-name>-<id>.md` per step, using exactly these fields:

```markdown
# Step <id>

- id: <id>
- depends_on: [<ids>]          # ids of steps that must finish first; [] if none
- route: mechanical | judgment # judgment = no clean deterministic answer → route
                               #   back to the expensive model or a human
- objective: <one sentence>
- files_in_scope:              # exact paths ONLY; the worker may change nothing else
    - <path>
- context: |
    <the distilled slice of the brief + roadmap this worker needs, assuming zero
    other knowledge. For anything produced by an earlier step, reference it as
    "files changed in step <id>" — the supervisor resolves the actual paths/content
    from the ledger at run time.>
- actions: |
    <concrete, ordered instructions, as close to executable as possible. If depends_on
    is non-empty, the FIRST action asserts that each dependency's key artifact exists
    (exact file path, or exact symbol in a named file) and says: if absent, STOP and
    report "missing base" in the report file — do not fetch, merge, or improvise>
- acceptance: |
    <a command to run> → <the EXACT expected result: exact stdout, exit code, or
    resulting file state>
- rollback: |
    <how to undo this step>
```

Field notes:

- **route** — `mechanical`: a clean, checkable answer a cheap worker can reach and you can
  verify with a command. `judgment`: needs taste or an open decision — mark it so the
  supervisor sends it to the expensive model or a human, not a cheap worker.
- **files_in_scope** — the contract that makes parallelism safe: the worker touches only
  these paths, and the supervisor rejects the step if anything else changed. Always list
  the step's own `<plan-name>-<id>-report.md` — it lands in the step's single commit and
  must pass the scope check.
- **actions** — when `depends_on` is non-empty, the first action asserts a concrete
  artifact of each dependency (exact path, or exact symbol in a named file) and tells the
  worker to STOP and report a missing base if the check fails — never to fetch, merge, or
  self-repair. This makes every worker an independent detector of a mis-based worktree,
  behind the supervisor's own gate. End `actions` at the step's real work: the report
  format and one-commit protocol are fixed (see Worker report & commit protocol) — do not
  restate them per step, and NEVER ask the worker to record its own commit SHA in the
  report (it cannot exist until after the commit that would contain it).
- **acceptance** — a real command plus its exact expected result; "looks right" is not
  acceptance. Prefer deterministic checks (a passing test, exact stdout, an exit code, a
  file with specific content). It must exercise every compile/test surface the change can
  break: a step that edits a shared package but builds only that package can pass while
  breaking its dependents. Dry-run every check against the exact content your `actions`
  mandate before committing the step: a check the honest result cannot satisfy — a grep
  count your own verbatim code breaks, a literal (`## Heading`) a Contents link will never
  contain — is a decomposition bug that invites the worker to game it. Prefer anchored
  patterns and presence checks over exact counts.

**Sizing.** Keep each step small enough for a weak, low-context worker to execute *and*
self-check. If it spans many files, needs judgment, or can't take a crisp acceptance
command, split it — or route it `judgment`. Keep the file lean: every token competes with
the worker's room to work, so write `context` and `actions` dense and imperative.

**Specification level.** Calibrate how literally `actions` dictate the work. Embed exact
verbatim content (code the worker applies as-is) only where a plausible-looking variant
would be silently wrong — sign/perspective conventions, exact formulas, delicate API
contracts. For greenfield files with a strong `acceptance` (new tests, examples, docs),
specify requirements and let the worker write the content — a well-briefed cheap worker
produces clean new code, and writing every step verbatim makes decomposition the
pipeline's dominant cost.

**Parallelism rule.** Steps whose dependencies are satisfied at the same time run
concurrently, each in its own git worktree. Their `files_in_scope` **must be pairwise
disjoint** so the supervisor can merge without conflict. If two units of work must touch
the same file, fold them into one step or order them with `depends_on`. A downstream merge
conflict means two co-parallel scopes overlapped — a decomposition bug, which the
supervisor bounces back to you as a revision.

Disjointness has a content-level analogue: a step that RECORDS facts about a file it does
not touch — line-number links, counts, anchors, quoted signatures — is coupled to every
co-parallel step that edits that file. Every step passes and the merged result is still
stale. Give such a step `depends_on` those siblings, or strip the volatile facts from what
it writes.

**Gate steps.** A phase — especially the last — may end with a verification-only step:
`files_in_scope` = its own report alone; `actions` = run the phase/project Definition of
Done checks and record command, expected, actual, PASS/FAIL per item plus an overall
verdict. An honestly-failing report is a SUCCESSFUL gate step — the supervisor routes the
failure. Give a gate step checks on project state only, never checks its own report
perturbs (working-tree cleanliness, "everything committed") — those belong to the
supervisor.

## Inputs & orientation

Read, in order:

1. `<plan-name>-brief.md` — the goal, context, constraints, project Definition of Done.
2. `<plan-name>-roadmap.md` — the **target phase**: its objective, scope, and phase
   Definition of Done. Your steps must collectively satisfy that DoD.
3. `<plan-name>-ledger.md` — the actual current state (completed steps, their output files
   and commit SHAs). This matters most when revising.

You are given the **phase number**. If a **revision note** is present (from the supervisor
or the user) → Operation B; otherwise → Operation A.

## Operation A — decompose a phase (fresh)

1. From the target phase, enumerate the atomic units of work that together meet the phase
   DoD.
2. Assign each an `id` and a `route`. Route anything without a clean, command-checkable
   answer as `judgment`.
3. Set `depends_on` where one step needs another's output. Keep the graph as flat as
   possible so more steps run in parallel.
4. Assign **disjoint** `files_in_scope` to steps that will be ready at the same level.
   Where scopes would overlap, serialize with `depends_on` or merge them.
5. Into each `context`, distill exactly the slice of the brief and roadmap that worker
   needs — no more. Reference earlier outputs as "files changed in step `<id>`".
6. Write concrete `actions` — opening with the dependency-artifact assertion whenever
   `depends_on` is non-empty — an `acceptance` command with its exact expected result, and
   a `rollback`.
7. Write one `<plan-name>-<id>.md` per step, in the ledger's `artifacts-dir`.
8. Register every step in the ledger's **Steps** section: `id | phase | status=pending |
   files (from files_in_scope) | commit (blank)`.
9. Commit the step files and the ledger update together — message
   `decompose(<plan-name>): phase <N> steps`. Plan state is versioned like everything
   else: the revision loop relies on history for which version of a step a worker actually
   ran against.

## Operation B — revise

A revision note means a prior step failed or the plan was wrong — you are **correcting**,
not starting over.

1. Read the ledger for the **actual** current state: which steps completed (leave them
   alone), which failed, and what already changed on disk.
2. Read the revision note: which step failed, its acceptance result vs. expectation, and
   the supervisor's root-cause reading.
3. Emit **only the corrected and/or added** `<plan-name>-<id>.md` files — never re-emit
   completed steps. Adjust `depends_on`, `files_in_scope`, `actions`, or `acceptance` to
   fix the actual failure (re-partition overlapping scopes, split a too-large step, tighten
   a vague acceptance command).
4. Update the ledger's **Steps** registry: mark the failed step superseded and add the new
   ids as `pending`.
5. Commit the corrected/added step files and the ledger update together — message
   `decompose(<plan-name>): revise phase <N>`. The superseded version must stay reachable
   in history; never leave a revision sitting uncommitted in the working tree.

## Pitfalls

- **The worker knows nothing else.** If a fact isn't in the step's `context` or `actions`,
  it isn't available — projection is the whole job.
- **Acceptance must be executable, exact, and honestly satisfiable** — a command plus its
  precise expected result, no "verify it works"; dry-run every check against the content
  your own actions mandate.
- **Keep co-parallel scopes disjoint** — overlap among steps that run together causes merge
  conflicts and forces a revision.
- **Scope-disjoint is not coupling-free** — a step embedding facts derived from a file a
  co-parallel sibling edits (line links, counts, signatures) must `depends_on` that sibling
  or drop those facts.
- **Dependent steps assert their base** — open by checking a concrete artifact from each
  dependency and stop on absence; a worker detects a wrong or stale base, never repairs one.
- **Prefer plain file ops in actions** — `rm` + `git add -A <paths>` over `git rm`/`git mv`:
  worker sandboxes may block the git forms behind permission prompts, stalling the step.
- **Distill, don't dump** — project the relevant slice of the brief, not the whole thing.
- **On revision, touch only what's broken** — never re-decompose completed work.
- **Finish with a commit** — both operations end by committing the step files plus the
  ledger update; an emit that never lands in history can't be audited or revised against.
- **Don't clobber** — leave valid existing step files and completed ledger entries intact.

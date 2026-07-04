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

You take a single phase and break it into **steps**, one file each, sized for a weak,
low-context worker. The defining constraint: **the worker sees ONLY its step file** —
it has none of the brief, the roadmap, or any sibling step. So you must **project**
whatever the worker needs out of the brief and roadmap into each step's self-contained
`context`. Anything you leave out does not exist as far as the worker is concerned.

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
- A **worker** is a subagent the supervisor launches on a cheaper model (Sonnet) to
  execute one step. A worker sees ONLY its step file.
- A step routed `judgment` (no clean deterministic answer), or that fails repeatedly,
  escalates back to the expensive model or a human.

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

- **route** — `mechanical` means there is a clean, checkable right answer a cheap
  worker can reach and you can verify with a command. `judgment` means the step needs
  taste or an open decision; mark it so the supervisor sends it to the expensive model
  or a human instead of a cheap worker.
- **files_in_scope** — the contract that makes parallelism safe. The worker touches
  only these paths; the supervisor rejects the step if anything else changed.
- **actions** — when `depends_on` is non-empty, the first action must assert a concrete
  artifact of each dependency (an exact path, or an exact symbol in a named file) and
  tell the worker to STOP and report a missing base if the check fails — never to
  fetch, merge, or otherwise self-repair. This makes every worker an independent
  detector of a mis-based worktree, defense-in-depth behind the supervisor's own gate.
- **acceptance** — a real command plus its exact expected result. "Looks right" is not
  acceptance. Prefer deterministic checks: a passing test, an exact stdout, an exit
  code, a file that exists with specific content. Acceptance must exercise every
  compile/test surface the change can break: a step that edits a shared package but
  builds only that package can pass while breaking its dependents — enforce
  assumptions with acceptance, don't presume them.

**Sizing.** Prefer steps no larger than a weak, low-context worker can execute *and*
self-check. If a step spans many files, needs judgment, or can't be given a crisp
acceptance command, split it — or route it `judgment`. Keep the file itself lean too:
every token in a step competes with the worker's room to work, so write `context` and
`actions` dense and imperative — no filler.

**Parallelism rule.** Steps whose dependencies are all satisfied at the same time run
concurrently, each in its own git worktree. Their `files_in_scope` **must be pairwise
disjoint** so the supervisor can merge the worktrees without conflict. If two units of
work must touch the same file, either fold them into one step or order them with
`depends_on`. A merge conflict downstream means two co-parallel scopes overlapped —
that is a decomposition bug, and the supervisor will bounce it back to you as a
revision.

## Inputs & orientation

Read, in order:

1. `<plan-name>-brief.md` — the goal, context, constraints, project Definition of Done.
2. `<plan-name>-roadmap.md` — focus on the **target phase**: its objective, scope, and
   phase Definition of Done. The steps you emit must collectively satisfy that DoD.
3. `<plan-name>-ledger.md` — the actual current state (completed steps, their output
   files and commit SHAs). This matters most when revising.

You are told the **phase number** to decompose. Check whether a **revision note** is
present (passed by the supervisor, or by the user). No revision note → Operation A. A
revision note → Operation B.

## Operation A — decompose a phase (fresh)

1. From the roadmap's target phase, enumerate the atomic units of work that together
   meet the phase DoD.
2. Assign each an `id` and a `route`. Route anything without a clean, command-checkable
   answer as `judgment`.
3. Lay out dependencies: set `depends_on` where one step needs another's output. Keep
   the graph as flat as possible so more steps can run in parallel.
4. Assign **disjoint** `files_in_scope` to steps that will be ready at the same level.
   Where scopes would overlap, serialize them with `depends_on` or merge them.
5. Project context: into each step's `context`, distill exactly the slice of the brief
   and roadmap that worker needs — no more. Reference earlier steps' outputs as "files
   changed in step `<id>`".
6. Write concrete `actions` — opening with the dependency-artifact assertion whenever
   `depends_on` is non-empty — an `acceptance` command with its exact expected result,
   and a `rollback`.
7. Write one `<plan-name>-<id>.md` per step.
8. Register every step in the ledger's **Steps** section: `id | phase | status=pending
   | files (from files_in_scope) | commit (blank)`.
9. Commit the step files and the ledger update together — message
   `decompose(<plan-name>): phase <N> steps`. Plan state is versioned like everything
   else: the supervisor merges worker commits into this same branch, and the revision
   loop relies on history for which version of a step a worker actually ran against.

## Operation B — revise

A revision note means a prior step failed or the plan was wrong — you are **correcting**,
not starting over.

1. Read the ledger for the **actual** current state: which steps completed (leave them
   alone), which failed, and what already changed on disk.
2. Read the revision note: which step failed, its acceptance result vs. expectation, and
   the supervisor's root-cause reading.
3. Emit **only the corrected and/or added steps** — new or superseding `<plan-name>-<id>.md`
   files. Do not re-emit completed steps. Adjust `depends_on`, `files_in_scope`, `actions`,
   or `acceptance` to fix the actual failure (e.g. re-partition overlapping scopes, split a
   too-large step, tighten a vague acceptance command).
4. Update the ledger's **Steps** registry: mark the failed step superseded and add the new
   ids as `pending`.
5. Commit the corrected/added step files and the ledger update together — message
   `decompose(<plan-name>): revise phase <N>`. The superseded version must stay
   reachable in history; never leave a revision sitting uncommitted in the working tree.

## Pitfalls

- **The worker knows nothing else.** If a fact isn't in the step's `context` or
  `actions`, it isn't available. Projection is the whole job — do it thoroughly.
- **Acceptance must be executable and exact.** A command plus its precise expected
  result. No "verify it works" hand-waves.
- **Keep co-parallel scopes disjoint.** Overlapping `files_in_scope` among steps that
  run together causes merge conflicts and forces a revision.
- **Dependent steps assert their base.** A step with `depends_on` opens by checking a
  concrete artifact from each dependency and stops on absence — a worker must detect a
  wrong or stale base, never repair one.
- **Distill, don't dump.** Project the relevant slice of the brief into each step, not
  the entire brief.
- **On revision, touch only what's broken.** Emit corrected/added steps; never
  re-decompose completed work.
- **Finish with a commit.** Both operations end by committing the step files plus the
  ledger update; an emit that never lands in history can't be audited or revised against.
- **Don't clobber.** Leave valid existing step files and completed ledger entries intact.

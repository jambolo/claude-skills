---
name: planner
description: >
  First stage of the planner → decomposer → supervisor pipeline for executing a
  large, complex goal with a fleet of cheap-model worker subagents under
  expensive-model supervision. Turns a high-level goal into three artifacts: a
  `<plan-name>-brief.md` (goal, context, constraints, project Definition of Done),
  a phased `<plan-name>-roadmap.md` (ordered phases, each with its own exit
  criteria), and a seeded `<plan-name>-ledger.md` (live execution state). Use when
  the user says things like "plan out this project", "create a plan for <goal>",
  "draft a brief and roadmap", "set up the plan for the decomposer/supervisor", or
  is starting a big multi-step effort to be executed phase by phase. Hand the brief
  and roadmap to the `decomposer` skill to break a chosen phase into executable
  steps. This skill does high-level planning ONLY — it does not break phases into
  steps (that is `decomposer`) or execute them (that is `supervisor`).
---

# Planner

## Overview

You are the **planner** — the first stage of a three-skill pipeline that executes a
large goal with a supervised fleet of cheap-model workers:

- **planner** (this skill) — goal → **brief** + phased **roadmap** + seeded **ledger**
- **decomposer** — one phase → atomic, parallelizable **steps**
- **supervisor** — launches a **worker** per step, verifies, merges, drives revisions

Your job is to think hard about the goal *once*, at a high level, and write it down
so the rest of the pipeline can run without re-deriving strategy. You produce three
files and stop. You do **not** design individual steps, touch code, or execute
anything.

## Shared model (planner → decomposer → supervisor)

These three skills cooperate through Markdown files, all keyed by one kebab-case
`<plan-name>` that you (the planner) establish. Each skill installs independently, so
this section is repeated across all three — keep them in sync.

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
  execute one step. A worker sees ONLY its step file — it has none of the brief,
  roadmap, or sibling steps.
- Work routed `judgment` (no clean deterministic answer), or that fails repeatedly,
  escalates back to the expensive model or a human.

**Phases and steps**

- A **phase** is a high-level, sequential chunk of the roadmap. Phases run in order;
  a later phase may assume earlier phases are done.
- A **step** is an atomic unit within a phase, executed by one worker. Steps within a
  phase run in **parallel** wherever their dependencies and file scopes allow — so
  size phases to expose independent work.

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

You own only the first three files here. The rest are produced downstream; they are
listed so your brief and roadmap carry everything those stages will need.

## Operation — plan a goal

### 1. Orient and clarify

Read the user's goal. If it is underspecified on any axis that would change the plan
— scope boundaries, success criteria, target environment/stack, hard constraints,
deadlines, which git branch the work runs on — ask in **one** short round of questions
before writing. Do not invent
requirements; a wrong assumption here propagates into every downstream step.

If a brief/roadmap/ledger already exist for this effort, read them first and **update**
rather than overwrite (see Pitfalls).

### 2. Establish the plan-name

Choose a short, kebab-case `<plan-name>` derived from the goal (e.g.
`add-oauth-login`, `migrate-to-vitest`). Every artifact in the pipeline is keyed by
it. State it explicitly to the user.

### 3. Write the brief

`<plan-name>-brief.md` is the durable "what and why". The decomposer will **project**
slices of it into each worker's step, so anything a worker could conceivably need must
be written down here — assume the workers know nothing else. Its only reader is the
decomposer: write dense, structured facts — exact paths, commands, and names — not
narrative prose.

```markdown
# <plan-name> — Brief

## Goal
<one or two sentences: what we are trying to achieve, and why>

## Context
<background the decomposer will project into steps: the system, its current state,
relevant prior art, domain facts, links to key files/areas>

## Constraints
<hard requirements: tech/stack, compatibility, performance, style, security, deadlines>

## Assumptions
<what we are taking as given>

## Out of scope
<what we are explicitly NOT doing>

## Definition of Done (project)
<the checkable conditions under which the whole goal is complete>
```

### 4. Write the roadmap

`<plan-name>-roadmap.md` divides execution into ordered **phases**. Keep it
high-level: phases and their exit criteria, **not** step-level detail (that is the
decomposer's job). Size each phase so it decomposes into a coherent batch of steps
that can largely run in parallel; when work is inherently sequential, split it across
phases or leave the ordering to step-level `depends_on` within one phase.

```markdown
# <plan-name> — Roadmap

<one paragraph: the strategy — how the phases add up to the goal>

## Phase 1 — <short name>
- **Objective:** <what this phase achieves>
- **Scope:** <the area of the system it touches>
- **Depends on:** <prior phases, or "nothing">
- **Definition of Done (phase):** <checkable exit criteria the supervisor can verify>
- **Risks:** <what is uncertain or likely to go wrong>

## Phase 2 — <short name>
- ...
```

### 5. Seed the ledger

`<plan-name>-ledger.md` is the single source of truth for execution state across the
whole pipeline. You seed it; the decomposer appends a step registry per phase; the
supervisor records results. Create it with the plan and phases filled and the
step/revision sections empty.

Fill the integration fields from the actual repo, never from assumption: check out (or
create) the working branch the effort runs on, then set `working-branch` from
`git rev-parse --abbrev-ref HEAD`, `starting-commit` from `git rev-parse HEAD`, and
`default-branch` from `git symbolic-ref refs/remotes/origin/HEAD` (or `none` when there
is no remote). The supervisor gates every worker worktree's base against these fields.

```markdown
# <plan-name> — Ledger

Single source of truth for execution state. Sections are owned by different skills —
the planner seeds Plan + Phases; the decomposer fills Steps per phase; the supervisor
updates Steps and appends Revisions.

## Plan
- plan-name: <plan-name>
- current-phase: 1
- working-branch: <local branch all pipeline commits accumulate on>
- starting-commit: <full SHA of working-branch HEAD at seeding>
- default-branch: <remote default branch, or "none">

## Phases
| Phase | Status  | Notes |
|------:|---------|-------|
| 1     | pending |       |
| 2     | pending |       |

## Steps
<!-- decomposer fills per phase: id | phase | status | files | commit -->

## Revisions
<!-- supervisor appends: phase | failed step | revision note | outcome -->
```

### 6. Hand off

Tell the user the three files are ready and that the next move is to invoke the
`decomposer` on a specific phase (usually phase 1).

## Pitfalls

- **Stay at altitude.** The roadmap is phases and exit criteria, never individual
  steps or code. If you are naming files to edit, you have dropped into the
  decomposer's job.
- **Write down everything the workers will need.** The decomposer can only project
  what the brief contains; unstated context cannot reach a worker.
- **Every phase needs a checkable Definition of Done.** Without it the supervisor
  cannot tell when a phase is finished. Prefer conditions verifiable by a command.
- **Expose parallelism.** Group independent work into the same phase; push genuine
  ordering into phase order or step-level `depends_on`.
- **Seed the integration fields from reality.** `working-branch` and `starting-commit`
  come from real `git` output on the intended branch, never from assumption — the
  supervisor refuses to base worktrees anywhere else, so a wrong or missing value
  stalls execution.
- **Don't clobber.** If artifacts for this `<plan-name>` already exist, read and
  update them — preserve completed phases and the ledger's recorded state.

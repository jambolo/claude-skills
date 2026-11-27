# 0007. The brief and roadmap stay planner-owned for the plan's whole life; defects travel as amendment notes

**Status:** Accepted
**Date:** 2026-07-27
**Commits:** fbc90c0, 5cde06f, 5039ccd

## Context

The planner wrote the brief and roadmap once and stopped. When a later stage found one of them wrong mid-run there was no defined path: the stage could edit a file it did not own or work around the defect in step context. The review of the second full run (the four-in-a-row `two-player-game` plan) raised this as finding 6, and fbc90c0 answered it:

> - Brief amendment protocol (finding 6): brief/roadmap stay planner-owned for life; decomposer/supervisor send amendment notes, planner applies via new Operation B — amend. Shared-model section added to all three skills, kept in sync.

## Decision

From the Shared model:

> The brief and roadmap stay planner-owned for the plan's whole life. When the decomposer or supervisor finds them defective mid-execution — a wrong or unsatisfiable constraint, a stale fact, a mis-specified DoD — it does NOT edit them and does NOT work around the defect in step context or ledger notes.

The discoverer writes an **amendment note** (`trigger`, `defect` quoted exactly, `observed`, `root cause`, `suggested amendment`, `blast radius`). The planner alone edits the brief and roadmap — "in place, never an appendix" — checks the ripple across brief sections and Definitions of Done, appends a ledger Revisions row, and commits `amend(<plan-name>): <what>`. Pending steps that embed the stale text go through the decomposer's revision operation; "completed steps ran against the old text and stay untouched".

An amendment that strengthens a gate proceeds without asking. One that weakens a gate or changes scope or a Definition of Done returns `needs-human` unless the prompt already carries the human's approval.

## Rationale

The stated reason is the review finding itself (finding 6 of the four-in-a-row run review, removed from the tree in 3a67c8b and reachable at fbc90c0). The protocol's own text gives two further reasons: the `blast radius` in a note is "a lead, not a verdict", so the planner, which owns the whole document, decides what else changes; and a stage may not quietly weaken the checks it is judged by, hence the human approval for gate-weakening amendments.

## Consequences

- A defect found mid-run costs a planner invocation and usually a decomposer revision.
- The brief and roadmap are always current; there is no layer of overrides in step files or ledger notes to reconcile.
- Since 5039ccd the decomposer has no `Agent` tool and "returns `RESULT: needs-amendment` carrying the note"; its caller (the supervisor or `lead-developer`) spawns the planner and re-invokes the decomposer for the same phase. Before that (5cde06f) the decomposer spawned the planner itself.
- The planner has two operations, plan and amend.

## Alternatives considered

- **Let the discoverer edit the brief or roadmap**: rejected; ownership stays with the planner.
- **Work around the defect in step context or ledger notes**: explicitly forbidden.
- **Record amendments as an appendix**: rejected; edits are made in place.

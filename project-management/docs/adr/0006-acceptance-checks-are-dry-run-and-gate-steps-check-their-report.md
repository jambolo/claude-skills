# 0006. The decomposer proves its acceptance checks; coupled steps declare a dependency; a gate step's acceptance targets its report

**Status:** Accepted
**Date:** 2026-07-22
**Commits:** 61ac934, a9be4d0

## Context

[0002](0002-supervisor-verifies-against-ground-truth.md) makes a step's acceptance check the arbiter of pass or fail, so a wrong check fails correct work. The post-mortem of the first full run led to these items in 61ac934:

> - R6: decomposer dry-runs acceptance checks against its own mandated content
> - R7: content-level coupling (line links, counts) requires depends_on even with disjoint scopes; supervisor re-verifies embedded facts after parallel waves
> - R8: gate-step guidance — verify project state only, never the step's own report
> - R9: specification-level calibration (verbatim code vs spec + acceptance)
> - R11: briefs pin line numbers to the commit they were read at

A phase may end with a **gate step** that runs the phase's Definition of Done items and reports them. R8's first wording left open what that step's own acceptance should be; a9be4d0 ("Clarified the purpose of the final gate step in a phase") settled it.

## Decision

- **Dry run.** When a step's content is dictated by the decomposer, the decomposer runs the acceptance check against that content before emitting the step.
- **Content coupling is a dependency.** Two steps whose file scopes are disjoint but whose content refers to each other (a line link, a count) are ordered with `depends_on`; they do not run in the same wave.
- **Facts are pinned.** A brief that cites line numbers names the commit they were read at.
- **Gate steps.** The checks inside a gate step's `actions` are on project state only. Its `acceptance`

  > targets the report, never project state: presence checks that the report contains one command/expected/actual/PASS-FAIL row per DoD item plus an overall verdict — satisfiable by an honest FAIL exactly as by a PASS.

  The supervisor still runs the phase Definition of Done itself; the gate report "is a lead for which items to scrutinize — never a substitute for running the checks yourself".

## Rationale

From a9be4d0:

- "Never author the DoD commands themselves as the gate's acceptance: a broken project would turn an honest report into a failed step, and the supervisor's verification re-run would execute the full DoD a second time before its own phase check."
- "Report truthfulness is not the acceptance's job — the supervisor's phase Definition of Done run is what catches a fabricated PASS."
- A gate step never checks state "the step's own report perturbs (working-tree cleanliness, 'everything committed'); those belong to the supervisor."

## Consequences

- Decomposition costs more: the decomposer executes checks, not just writes them.
- Some steps that could run in parallel by file scope are serialized.
- A gate step can pass while the phase fails; the phase verdict is the supervisor's DoD run alone.
- R9 gives the decomposer a choice per step between dictating content verbatim and giving a specification plus acceptance; that distinction later became the `tier` field ([0014](0014-lite-steps-go-to-a-haiku-worker.md)).

## Alternatives considered

- **The DoD commands as the gate step's acceptance**: rejected in a9be4d0 for the reasons quoted above.
- **Rely on disjoint `files_in_scope` alone for parallel safety** (e3ff846): insufficient once steps embed facts about each other's output.

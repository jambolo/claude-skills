# 0014. Steps carry a `tier`; `lite` steps go to `worker-lite`, the same contract on Haiku

**Status:** Accepted
**Date:** 2026-10-22
**Commits:** 14d3312, 5cde06f, 3a67c8b, 5039ccd

## Context

Workers were always the cheap end of the pipeline: Sonnet from e3ff846. How cheap was adjusted twice. 14d3312 had the supervisor launch them at `effort: low`, reasoning that

> a `mechanical` step has a clean checkable answer — deep reasoning is wasted on it

and 5cde06f pinned `sonnet` / `low` in the new `worker` agent; 3a67c8b raised it to `medium`. Separately, the decomposer had been choosing, per step, between dictating content verbatim and giving a specification plus acceptance (R9 in [0006](0006-acceptance-checks-are-dry-run-and-gate-steps-check-their-report.md)). A step of the first kind asks even less of a worker. 5039ccd made that a routing decision.

## Decision

- A step file has a `tier` field, `standard` or `lite`, set by the decomposer: `lite` when "the content to apply is given verbatim" and the check is given, "nothing to design". "When in doubt, `standard`."
- The supervisor launches `worker` (`sonnet` / `medium`, `maxTurns: 80`) for a `standard` step and `worker-lite` (`haiku` / `medium`, `maxTurns: 40`) for a `lite` one.
- `worker-lite` is "the same contract on Haiku: its body must stay byte-identical to `worker`'s … only the frontmatter differs". `check-shared-model.sh` fails when the two bodies differ.
- `tier` is separate from `route`: a `judgment` step still goes to the supervisor or a person, never to either worker.

## Rationale

- A `lite` step has "content given verbatim to apply and a check to run, nothing to design", so the smallest model suffices.
- A benchmark confirmed the pin: `lite` steps run on Sonnet cost more than on Haiku with equal outcomes, so `worker-lite` stays on `haiku`.
- The agent feature allows a definition to specify its model and effort ([0010](0010-pipeline-stages-are-agents-with-pinned-model-and-effort.md)), so an appropriate work level can be chosen for each kind of step.

## Consequences

- The decomposer makes one more decision per step, and a wrong `lite` shows up as a failed step that is retried or revised.
- There are two worker files to keep identical below the frontmatter; the drift check enforces it and both are bumped together.
- Worker cost is a small share of a run's total next to the planner, decomposer, and supervisor, so this tier saves less than a change to a stage's pin.

## Alternatives considered

- **One worker for every step** (5cde06f through 3a67c8b): benchmarked as a control and found dearer on `lite` steps with no better outcome.
- **Lower effort on the one worker** (14d3312's `effort: low`): reversed to `medium` in 3a67c8b before tiers existed.
- **A separate body for `worker-lite`**: rejected; the contract is one contract, enforced byte for byte.

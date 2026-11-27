# 0012. Every agent launch passes `run_in_background: false`

**Status:** Accepted
**Date:** 2026-10-06
**Commits:** ab8453e

## Context

Every stage that spawns another — `lead-developer` spawning a stage, the supervisor spawning workers, the decomposer, or the planner — acts on the spawned agent's `RESULT:` line and on what it committed. The definitions said "foreground" in prose but passed no parameter. ab8453e ("Every agent launch now passes run_in_background: false") made it explicit in every launch instruction. From `lead-developer`:

> Pass `run_in_background: false` on every Agent call — the tool otherwise launches in the background, and each step below needs the stage's result before it continues. If the Agent tool does not list `run_in_background`, omit it — an unlisted parameter fails the call.

## Decision

Every Agent call in the family passes `run_in_background: false`. The parameter is omitted only when the Agent tool in the running harness does not list it. The rule is stated in the Shared model's "Calling a sibling agent" paragraph (all three copies), in `lead-developer`, and in the family `CLAUDE.md`.

## Rationale

The Agent tool launches in the background by default, and a caller whose launch went to the background may end its turn without waiting for the result. The escape clause exists because "an unlisted parameter fails the call".

## Consequences

- A caller is blocked for the whole of a child's run; the chain `lead-developer` → supervisor → worker is synchronous at every level.
- Parallel workers depend on foreground calls issued in one message running concurrently. That is not documented; the family `CLAUDE.md` records that "the 2026-10-22 smoke run showed they do (parallel steps' commits landed one second apart)", and the smoke test's parallelism check exists to detect a change.
- The rule depends on the Agent tool's parameter list, which is a harness fact to re-check after an upgrade.

## Alternatives considered

- **Say "foreground" in prose and pass nothing** (before ab8453e): the launch went to the background by default, and the caller could end its turn without the result.
- **Launch in the background and wait for the completion notice**: not taken; each caller's next step is defined in terms of the child's result.

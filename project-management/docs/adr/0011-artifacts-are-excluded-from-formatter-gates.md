# 0011. Pipeline artifacts are excluded from formatter gates, never formatted to pass them

**Status:** Accepted
**Date:** 2026-09-18
**Commits:** af9f8fd, 3a67c8b, 5039ccd

## Context

Artifacts are committed on the working branch ([0004](0004-plan-artifacts-are-committed-as-the-plan-proceeds.md)), so in a project with Prettier, markdownlint, dprint, or a pre-commit hook they fall under the project's Markdown gates. A formatter that rewrites them changes strings the pipeline compares exactly. af9f8fd ("Agents now prevent any formatter from running on artifact files") added to the Shared model:

> Never run a formatter or auto-fixer (Prettier, a lint `--fix`, a pre-commit hook's rewrite) on an artifact: artifacts hold byte-exact literals — expected outputs, quoted defect text, grep patterns — that the pipeline compares literally, and reformatting silently corrupts them.

A cloud review of that change (`project-management/code-review_2026-10-16.md`) found the first implementation did not work as intended: a glob was given where pre-commit's `exclude:` takes a regex, `.markdownlintignore` was used for a tool (markdownlint-cli2) that never reads it, ignore files were edited before checking out the branch they belong on, the planner's "fallback" always ran, and a worker had no instruction for a hook that rewrote its report. 3a67c8b fixed each.

## Decision

- No stage runs a formatter or auto-fixer on a file in `artifacts-dir`.
- If a repo gate covers `artifacts-dir`, "the artifacts are excluded from that gate — by `lead-developer` at project planning, else by the planner at seeding — never formatted to pass it". The exclusion uses the mechanism each detected tool actually reads (a pre-commit `exclude:` regex, `ignores` for markdownlint-cli2, and so on) and is committed with the plan. This is the one project file the planner may edit.
- The planner surveys gates before writing anything, and skips the survey when its prompt says `lead-developer` already handled exclusions.
- A tool with no recognized ignore mechanism is a question for a person: `lead-developer` asks; the planner returns `needs-human` having written nothing.
- Mid-run, an agent that finds a gate failing on artifacts returns `RESULT: needs-human`; "it never formats them and never edits the gate's config". A worker whose commit hook rewrites or rejects an artifact stops with `needs-human` — "no re-stage, no `--no-verify`, no retry" — and the supervisor routes that straight up without a retry or revision.

## Rationale

- Artifacts "hold byte-exact literals … that the pipeline compares literally, and reformatting silently corrupts them".
- A worker's report "holds verbatim output that must stay byte-exact".
- The 3a67c8b refinements each answer a numbered finding of the 2026-10-16 review.

## Consequences

- The pipeline edits the host project's ignore configuration once, at planning, and tells the user what it added.
- `needs-human` became a worker outcome (worker 2.0.0, a major bump), distinct from `fail`.
- Since 5039ccd, detection is `find-formatter-gates.sh`, which reports per tool whether the artifacts are already covered and "the exact entry to add" ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)).
- Artifacts do not follow the host project's Markdown style, consistent with [0001](0001-three-stages-cooperate-only-through-markdown-artifacts.md): they are not written for people.

## Alternatives considered

- **Format artifacts so the gate passes**: rejected; it corrupts the literals.
- **Bypass hooks with `--no-verify`**: forbidden to the worker.
- **One glob for every tool's ignore file** (af9f8fd): wrong for pre-commit and markdownlint-cli2, so artifacts were reported excluded while still being rewritten; replaced by per-tool syntax in 3a67c8b.

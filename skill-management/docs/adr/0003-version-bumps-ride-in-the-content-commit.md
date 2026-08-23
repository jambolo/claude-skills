# 0003. Version bumps ride in the same commit as the content edit, under fixed semver semantics

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca, 5cde06f

## Context

Drift being an error ([0002](0002-manifest-is-the-comparison-basis-drift-is-an-error.md)) only helps if the bump actually happens. 7f7a7ca wrote the obligation into the root `CLAUDE.md` as a commit-level rule, not a release ritual:

> After changing a skill's content, bump its `version:` (patch = wording, minor = new capability, major = changed operations/inputs/artifact formats) **and** update its manifest entry in the same commit.

The three semver levels are defined against what a *caller* sees, not against code size. `skill-version-check`'s own Bookkeeping section spells it out:

> - **patch** — wording, typos, clarifications that do not change behavior.
> - **minor** — new capability or new template, backward compatible; for an agent, also a changed `model`, `effort`, `tools`, or `maxTurns`.
> - **major** — changed operation names, inputs, or artifact formats; anything that invalidates how a caller invokes it — including changing an entry's kind between skill and agent.

5cde06f extended both lists to agents, adding `model`/`effort`/`tools`/`maxTurns` as minor and a skill↔agent kind change as major — because those frontmatter fields are the agent's interface just as operation names are a skill's.

The rule also carries an explicit exception for content that is physically duplicated across leaves:

> Editing the `project-management` shared "Shared model" section means bumping all three of `planner`, `decomposer`, `supervisor`.

## Decision

Any commit that changes a `SKILL.md` or `AGENT.md` body also bumps that entry's `version:` and updates its `skills-manifest.json` entry, in that same commit. The level is chosen by caller impact: patch for wording, minor for a backward-compatible capability (for an agent, also a changed `model`, `effort`, `tools`, or `maxTurns`), major for changed operation names, inputs, artifact formats, or a change of kind. When one edit lands in several files — the `project-management` "Shared model" section — every affected entry is bumped together.

## Consequences

- A commit is the unit of release. There is no separate publish step, and no window in which the repo is internally inconsistent.
- Editing the duplicated "Shared model" section now requires bumping three versions and three manifest entries, which is the standing tax of that duplication.
- Converting a leaf from skill to agent is a major bump, so it is visible in the manifest as a version jump and not just as a new `kind` field.
- Reviewers can check the rule mechanically: run the comparison script and require an empty drift section, rather than reading the diff for missed bumps.
- Wording-only patch bumps make the version history noisy, but the noise is what keeps the manifest honest — a suppressed bump is indistinguishable from a forgotten one.

## Alternatives considered

None recorded.

# Architectural Decision Records — `skill-management` family

Decisions that shape the `skill-version-check` skill, numbered in the order they were made (commit date). The family is one skill — `skill-management/skill-version-check/` — carrying a `SKILL.md` plus the only `scripts/` directory in the repo (`Compare-SkillVersions.ps1`, `compare-skill-versions.sh`). It has no agents and no templates. Several of its decisions are repo-wide invariants that live in the root `CLAUDE.md` because they bind every family: the semver line, the manifest, and the same-commit bump rule.

The family landed in two commits. Everything numbered 0001–0006 comes from 7f7a7ca, which introduced versioning across the whole repo at once; 0007 comes from 5cde06f, which added agents and amended 0006. Ordering within 7f7a7ca is by dependency, not by diff order — the skill was already at version 1.2.1 at its first commit, so the iterations that produced it are not in history.

| # | Title | Status | Date | Superseded by |
| --- | --- | --- | --- | --- |
| [0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md) | Every skill carries a semver `version:`, mirrored by a root `skills-manifest.json` | Accepted | 2026-08-21 | — |
| [0002](0002-manifest-is-the-comparison-basis-drift-is-an-error.md) | The manifest is the comparison basis; manifest-vs-repo disagreement is "drift" and blocks Sync | Accepted | 2026-08-21 | — |
| [0003](0003-version-bumps-ride-in-the-content-commit.md) | Version bumps ride in the same commit as the content edit, under fixed semver semantics | Accepted | 2026-08-21 | — |
| [0004](0004-refresh-first-ff-only-degrade-to-local-snapshot.md) | Every operation starts with a fast-forward-only pull from a verified upstream, and degrades to the local snapshot on failure | Accepted | 2026-08-21 | — |
| [0005](0005-comparison-ships-as-two-hand-synced-script-ports.md) | The comparison ships as a bundled script, in two hand-kept-in-sync ports | Accepted | 2026-08-21 | — |
| [0006](0006-orphans-are-reported-not-deleted-except-superseded.md) | Installed items the manifest does not own are reported, never deleted — except a superseded kind-change leftover | Accepted | 2026-08-21 | — |
| [0007](0007-agents-share-the-manifest-via-a-kind-discriminator.md) | Skills and agents are peer kinds in one manifest, distinguished by a mandatory `kind` | Accepted | 2026-08-23 | — |

## Amended decisions

No ADR is superseded. One was amended in place rather than replaced:

| Decision | Original | Amendment |
| --- | --- | --- |
| Orphan handling ([0006](0006-orphans-are-reported-not-deleted-except-superseded.md)) | 7f7a7ca — orphans are informational, "never delete them" | 5cde06f — one exception for a `superseded` kind-change leftover, removable with confirmation, because the skill→agent conversions in that commit left both copies dispatching |

## Commit key

| SHA | Date | Subject |
| --- | --- | --- |
| 7f7a7ca | 2026-08-21 | Added `skill-version-check` skill. Added version numbers to all skills. |
| 5cde06f | 2026-08-23 | project-management: Converted planner and supervisor skills to agents … skill-version-check: now handles agents |

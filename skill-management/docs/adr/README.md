# Architectural Decision Records — `skill-management` family

Decisions that shape the `skill-version-check` and `script-version-check` skills, numbered in the order they were made (commit date; see the note under the table for the one exception). The family began as one skill — `skill-management/skill-version-check/` — carrying a `SKILL.md` plus a `scripts/` directory (`Compare-SkillVersions.ps1`, `compare-skill-versions.sh`); ea969b0 added `script-version-check` with the same shape. It has no agents and no templates. Several of its decisions are repo-wide invariants that live in the root `CLAUDE.md` because they bind every family: the semver line, the manifest, and the same-commit bump rule.

The family landed in two commits. Everything numbered 0001–0006 comes from 7f7a7ca, which introduced versioning across the whole repo at once; 0007 comes from 5cde06f, which added agents and amended 0006. 0008 records 66dbede, which superseded 0006. 0009 records ea969b0 (the second skill and the manifest rename) and 0010 records 9b1b81c (removal tombstones). Ordering within 7f7a7ca is by dependency, not by diff order — the skill was already at version 1.2.1 at its first commit, so the iterations that produced it are not in history.

| # | Title | Status | Date | Superseded by |
| --- | --- | --- | --- | --- |
| [0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md) | Every skill carries a semver `version:`, mirrored by a root `skills-manifest.json` | Accepted | 2026-08-21 | — |
| [0002](0002-manifest-is-the-comparison-basis-drift-is-an-error.md) | The manifest is the comparison basis; manifest-vs-repo disagreement is "drift" and blocks Sync | Accepted | 2026-08-21 | — |
| [0003](0003-version-bumps-ride-in-the-content-commit.md) | Version bumps ride in the same commit as the content edit, under fixed semver semantics | Accepted | 2026-08-21 | — |
| [0004](0004-refresh-first-ff-only-degrade-to-local-snapshot.md) | Every operation starts with a fast-forward-only pull from a verified upstream, and degrades to the local snapshot on failure | Accepted | 2026-08-21 | — |
| [0005](0005-comparison-ships-as-two-hand-synced-script-ports.md) | The comparison ships as a bundled script, in two hand-kept-in-sync ports | Accepted | 2026-08-21 | — |
| [0006](0006-orphans-are-reported-not-deleted-except-superseded.md) | Installed items the manifest does not own are reported, never deleted — except a superseded kind-change leftover | Superseded | 2026-08-21 | [0008](0008-unowned-installs-are-ignored-except-superseded.md) |
| [0007](0007-agents-share-the-manifest-via-a-kind-discriminator.md) | Skills and agents are peer kinds in one manifest, distinguished by a mandatory `kind` | Accepted | 2026-08-23 | — |
| [0008](0008-unowned-installs-are-ignored-except-superseded.md) | Installed items the manifest does not own are ignored — except a superseded kind-change leftover | Accepted | 2026-09-24 | — |
| [0009](0009-script-repos-get-a-sibling-skill-not-a-third-kind.md) | Bash-script repos get a sibling skill (`script-version-check`) over the same manifest model, not a third kind | Accepted | 2026-08-25 | — |
| [0010](0010-removals-are-tombstones-in-the-manifest.md) | A removal is a tombstone in the manifest's `removed` array, so Sync can offer to delete the installed copy | Accepted | 2026-11-10 | — |

0009 is out of date order: it records ea969b0 (2026-08-25), which predates 0008's commit but was written up after it; numbers are not reused.

## Amended decisions

0006 was amended in place once before 0008 superseded it:

| Decision | Original | Amendment |
| --- | --- | --- |
| Orphan handling ([0006](0006-orphans-are-reported-not-deleted-except-superseded.md)) | 7f7a7ca — orphans are informational, "never delete them" | 5cde06f — one exception for a `superseded` kind-change leftover, removable with confirmation, because the skill→agent conversions in that commit left both copies dispatching |
| Unowned installs ([0008](0008-unowned-installs-are-ignored-except-superseded.md)) | 66dbede — ignored, except `superseded` | 9b1b81c — second exception for a `removed` tombstone ([0010](0010-removals-are-tombstones-in-the-manifest.md)) |
| Manifest ([0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md)) | 7f7a7ca — `skills-manifest.json`, a pure mirror of frontmatter | ea969b0 — renamed `manifest.json`; 9b1b81c — gains the hand-maintained `removed` array |
| Script ports ([0005](0005-comparison-ships-as-two-hand-synced-script-ports.md)) | 7f7a7ca — two ports, LF-pinned | ea969b0 — a second pair in `script-version-check`; c262cb3 — bash ports strip `\r` from Windows `jq` output |

## Commit key

| SHA | Date | Subject |
| --- | --- | --- |
| 7f7a7ca | 2026-08-21 | Added `skill-version-check` skill. Added version numbers to all skills. |
| 5cde06f | 2026-08-23 | project-management: Converted planner and supervisor skills to agents … skill-version-check: now handles agents |
| 66dbede | 2026-09-24 | skill-version-check: Skills and agents that are not owned by the manifest are ignored unless the kind was changed (and moved as a result). |
| ea969b0 | 2026-08-25 | Added new script-version-check skill. Renamed skills-manifest.json to manifest.json. |
| 9b1b81c | 2026-11-10 | skill management: removed skills and scripts are marked as such (rather than just removing the entry) so that a sync will remove them. |
| c262cb3 | 2026-11-22 | skill management: Fixed line-ending problems in the compare-version scripts. |

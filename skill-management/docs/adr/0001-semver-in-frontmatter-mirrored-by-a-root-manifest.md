# 0001. Every skill carries a semver `version:`, mirrored by a root `skills-manifest.json`

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca, 5cde06f

## Context

Before 7f7a7ca nothing in the repo recorded what version of a skill a user had installed. Installation is a folder copy to `~/.claude/skills/<name>/`, so the installed copy and the authoring source are physically unrelated files; there is no package manager, no lockfile, and no install receipt. The only thing the two copies share is the `SKILL.md` frontmatter itself.

7f7a7ca added two things at once: a `version:` line to every skill's frontmatter, and `skills-manifest.json` at the repo root. The root `CLAUDE.md` gained the rule in the same commit:

> Every `SKILL.md` carries a semver `version:` line directly under `name:`, and `skills-manifest.json` at the repo root mirrors it for every skill (including `skill-version-check` itself).

The version alone would have been enough to compare one known skill, but not to answer "what should be installed?" — that needs a repo-side inventory. `skills-manifest.json` supplies it: `name`, `version`, `kind`, `path`, `family` per entry (`kind` arrived with 5cde06f — [0007](0007-agents-share-the-manifest-via-a-kind-discriminator.md)). `path` is what lets the scripts find the source file without inferring the family folder, and `name` is what pins the install location, because the repo-wide rule is that the leaf folder name equals the frontmatter `name`:

> Leaf folder name must equal frontmatter `name` (kebab-case). Installation and discovery assume this — the enclosing category folder is not part of the name.

The manifest also fixes the ordering and completeness rules so that regenerating it is deterministic:

> Entries are ordered by family, then by name within the family. Every skill and agent in the repo appears, including this skill. A frontmatter with no `version:` is an error — add `version: 1.0.0` (directly under `name:`) rather than omitting the entry from the manifest.

## Decision

Every `SKILL.md` and `AGENT.md` carries a semver `version:` directly under `name:`. `skills-manifest.json` at the repo root is the inventory of everything the repo owns — one entry per leaf, carrying `name`, `version`, `kind` (`"skill"` or `"agent"`, always present), `path` (`<family>/<name>`, forward slashes), and `family` — and it mirrors the frontmatter version of every entry. A missing `version:` is an error, not an excuse to omit the entry. The manifest is versioned itself (`manifestVersion`) and carries the default install roots.

## Consequences

- Version comparison works over a plain file copy: read `version:` out of both frontmatters, no install metadata required.
- The manifest is a second place the version is written, so it can disagree with the source — that failure mode is named and handled in [0002](0002-manifest-is-the-comparison-basis-drift-is-an-error.md).
- Adding a skill means adding a manifest entry; forgetting one makes the skill invisible to `skill-version-check` even though it exists in the repo.
- `path` in the manifest means the family folders stay purely organizational — moving a leaf between families is a manifest edit, not a rename of the installed artifact.
- Skills that predate 7f7a7ca are already installed without a `version:`, which is why `UNVERSIONED` exists as a distinct status rather than being treated as an error.

## Alternatives considered

None recorded.

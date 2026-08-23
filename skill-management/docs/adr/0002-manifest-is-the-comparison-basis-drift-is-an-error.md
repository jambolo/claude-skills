# 0002. The manifest is the comparison basis; manifest-vs-repo disagreement is "drift" and blocks Sync

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca

## Context

With the version written in two places ([0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md)) the checker has a choice: compare the installed copy against the repo's `SKILL.md`, or against the manifest entry. 7f7a7ca picked the manifest, and made the redundancy do work rather than hiding it. The report carries three version columns, not two:

> The script prints one row per manifest entry with `Name`, `Kind` (`skill` or `agent`), `Manifest` (version in `skills-manifest.json`), `Repo` (version in the repo's `SKILL.md` / `AGENT.md`), `Local` (version in the installed copy), and a status

Only `Local` vs `Manifest` produces a status — `Compare-Version -Local $localVersion -Manifest $s.version` in `Compare-SkillVersions.ps1`. `Repo` exists solely to catch the manifest lying, and that comparison gets its own section:

> **Manifest drift** — `Manifest` != `Repo`. The manifest is stale relative to the repo; fix with Bookkeeping before trusting any status column.

Drift is not advisory. It is a hard gate on the write path:

> Refuse to sync while manifest drift exists — fix with Bookkeeping, otherwise you would install a version the manifest misreports.

The root `CLAUDE.md` states the same rule as a repo invariant rather than a skill behavior — "**The two must always agree** — a mismatch is 'manifest drift' and is treated as an error" — and the repo's own change-validation checklist ends on it:

> Version/manifest state: `pwsh skill-management/skill-version-check/scripts/Compare-SkillVersions.ps1 -RepoRoot .` … the "Manifest drift" section must be empty.

## Decision

The installed version is compared against the **manifest** version; that comparison alone produces a row's status. The repo frontmatter version is read as a third column purely to detect that the manifest is stale. Any row where `Manifest != Repo` is reported as manifest drift, and drift makes the status column untrustworthy: Sync refuses to run until Bookkeeping clears it. A drift-free manifest is a repo invariant, checked as part of validating any change.

## Consequences

- The manifest is the published contract. An edit committed to a `SKILL.md` without a manifest bump is invisible to every installed copy — the checker reports `OK` for a stale install until drift is noticed.
- Drift is detected mechanically instead of relying on the author remembering, which is what makes the same-commit bump rule ([0003](0003-version-bumps-ride-in-the-content-commit.md)) enforceable.
- Both script ports must compute and print the drift section identically, since the repo's validation step greps for it.
- A user with no clone-side access still gets a correct answer: the manifest travels with the repo, so a `Check` needs no network beyond Refresh.

## Alternatives considered

None recorded.

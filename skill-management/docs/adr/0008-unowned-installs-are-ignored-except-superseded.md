# 0008. Installed items the manifest does not own are ignored — except a superseded kind-change leftover

**Status:** Accepted
**Date:** 2026-09-24
**Commits:** 66dbede
**Supersedes:** [0006](0006-orphans-are-reported-not-deleted-except-superseded.md)

## Context

[0006](0006-orphans-are-reported-not-deleted-except-superseded.md) had both scripts diff the install roots against the manifest and report every unowned install as an informational orphan. `~/.claude/skills/` and `~/.claude/agents/` are shared directories, so that list was mostly skills and agents from other sources — noise in a report about this repo's entries, and an invitation to treat them as this repo's business.

66dbede narrowed the orphan scan to the one case that needs action: an installed item whose name the manifest lists under the other kind. The report section was renamed from **Installed but not in manifest** to **Superseded leftovers**, and the `--json` / `-Json` `orphans` array now carries only `superseded` rows.

## Decision

Installed skills and agents that the manifest does not own are out of scope: the scripts skip them, and the report never mentions them. The single exception is unchanged from 0006: an installed item whose name matches a manifest entry of the *other* kind is a leftover from a skill↔agent conversion that still dispatches alongside its replacement, so Check lists it under **Superseded leftovers** and Sync offers to remove it — only with the user's explicit confirmation, and declining is accepted with a warning. `~/.claude/plugins/**` is never read, reported, or modified.

## Consequences

- The report covers only this repo's entries plus actionable leftovers; unowned installs are invisible to this skill.
- The report header and the JSON `orphans` contents changed, a breaking output-format change: skill-version-check went to 4.0.0.
- Unowned items are still never deleted — the destructive path stays the narrow, name-derived `superseded` case.
- Both ports must apply the same filter and compute the `superseded` label identically.

## Alternatives considered

None recorded.

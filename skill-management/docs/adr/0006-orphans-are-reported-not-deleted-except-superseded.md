# 0006. Installed items the manifest does not own are reported, never deleted — except a superseded kind-change leftover

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca, 5cde06f

## Context

`~/.claude/skills/` and `~/.claude/agents/` are shared directories. This repo owns some of what lives there; the rest comes from other sources, is hand-authored, or is left over from repos that no longer exist. Both scripts enumerate the install roots and diff against the manifest's names, producing an orphan list. 7f7a7ca's rule for that list was absolute:

> **Installed but not in manifest** — folders under the install root this repo does not own. Report as informational only; never delete them.

5cde06f introduced one exception, forced by the skill→agent conversions in the same commit ([0007](0007-agents-share-the-manifest-via-a-kind-discriminator.md)). Converting `planner` from a skill to an agent leaves `~/.claude/skills/planner/` installed next to the new `~/.claude/agents/planner.md`, and both dispatch:

> an orphan whose `Kind` reads `skill (superseded by agent)` (or the reverse) is a leftover from an entry that changed kind in the repo. Left in place it still dispatches under the old name alongside the new one, so call it out explicitly and offer to remove it as part of Sync — only ever with the user's confirmation.

The detection is name-based and symmetric in both ports: an orphan under the skills root whose name matches a manifest entry of kind `agent` is labeled `skill (superseded by agent)`, and the reverse for the agents root. Sync's removal step is gated and non-fatal — "Skip silently if the user declines — but warn that both will dispatch."

Plugin-provided skills are excluded from the whole family, orphan reporting included: "Plugin skills and agents (`~/.claude/plugins/**`) are out of scope. Do not read, report, or modify them."

## Decision

Anything installed under either install root that the manifest does not list is reported as informational and never deleted. The single exception is an orphan whose name matches a manifest entry of the *other* kind: it is a leftover from a skill↔agent conversion, it still dispatches alongside its replacement, so Check labels it `superseded` and Sync offers to remove it — only with the user's explicit confirmation, and declining is accepted with a warning. `~/.claude/plugins/**` is never read, reported, or modified.

## Consequences

- Skills from other sources and hand-written ones are safe from this skill; the report tells the user they exist and stops there.
- The one destructive path is narrow and name-derived, so it cannot fire on anything the manifest does not already claim under a different kind.
- A stale duplicate that is *not* a kind change — a skill deleted from the repo entirely — still cannot be cleaned up by this skill, by design.
- Both ports must compute the `superseded` label identically, since it is what gates the deletion offer.

## Alternatives considered

None recorded.

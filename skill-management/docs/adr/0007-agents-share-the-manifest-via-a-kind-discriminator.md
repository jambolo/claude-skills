# 0007. Skills and agents are peer kinds in one manifest, distinguished by a mandatory `kind`

**Status:** Accepted
**Date:** 2026-08-23
**Commits:** 5cde06f

## Context

5cde06f converted `planner`, `decomposer`, and `supervisor` from skills to Claude Code agent definitions and added `worker`, introducing a second install target with a different shape. An agent leaf holds one `AGENT.md`, and it installs to a *file*, not a folder:

> A skill leaf is copied whole to `~/.claude/skills/<name>/`; an agent leaf's `AGENT.md` is copied to the single file `~/.claude/agents/<name>.md`.

The same commit taught `skill-version-check` about them without adding a second manifest, a second script, or a second operation set. A per-entry discriminator carries the whole difference:

> **Kinds.** Every manifest entry carries `"kind"`, either `"skill"` or `"agent"`. There is no default — an entry with a missing or unrecognized `kind` is an error, and both scripts refuse the whole manifest rather than guessing.

The two kinds are peers, not a default plus a special case. That is a naming constraint as much as a behavioral one: every name that denotes one kind says which kind it denotes. The pre-existing `installRoot` became `skillInstallRoot` next to the new `agentInstallRoot`, the `skills` array became `entries`, and the leading report column became `Name` rather than `Skill` — otherwise every unqualified name would quietly mean "skill" while agents carried a qualifier, and the manifest's own vocabulary would contradict the design. `manifestVersion` went 1 → 2 in the same step.

Requiring `kind` rather than defaulting it is the other half. A defaulted discriminator turns a hand-edited entry that simply forgot its `kind` into a silent misread — compared as a skill, against a path that will never exist, reported as `MISSING` with no hint why. Rejecting the manifest outright names the offending entry instead.

Both ports gained one branch each — `SKILL.md` → `<skillInstallRoot>\<name>\SKILL.md` versus `AGENT.md` → `<agentInstallRoot>\<name>.md` — plus a `Kind` column and matching `-SkillInstallRoot` / `--skill-install-root` and `-AgentInstallRoot` / `--agent-install-root` flags; all six statuses, the drift section, and the summary line were reused unchanged, which is why `MISSING` was reworded from "no folder at install root" to "nothing at the install path".

Install for an agent is a plain copy, explicitly *not* a mirror, and the reason is the shared directory:

> there is nothing else to mirror, and the agents folder holds other agents the repo does not own, so never mirror or delete at the folder level

One further asymmetry has no analogue for skills and is surfaced in the report rather than in the scripts:

> Agent definitions are read at session start — tell the user a new or changed agent needs a new Claude Code session to take effect.

## Decision

Skills and agents are peer kinds sharing one `skills-manifest.json`. Every entry declares `"kind"` as `"skill"` or `"agent"`; there is no default, and a missing or unrecognized `kind` aborts the comparison with an error naming the entry. The manifest's array is `entries`, the skills install root is `skillInstallRoot` alongside `agentInstallRoot`, and `manifestVersion` is 2. The scripts branch on `kind` to select the source file (`SKILL.md` vs `AGENT.md`) and the install path (`<skillInstallRoot>/<name>/` vs `<agentInstallRoot>/<name>.md`), and share every status, section, column, and summary between the kinds; the leading table column is `Name`, not `Skill`. The script flags are `-SkillInstallRoot` / `--skill-install-root` and `-AgentInstallRoot` / `--agent-install-root`. A skill leaf is mirrored with delete semantics; an agent is copied as a single file, never mirrored at the folder level. Sync reports that a new or changed agent needs a new Claude Code session.

The file name `skills-manifest.json` is kept as-is: it is the anchor that repo-root resolution walks up to find, and renaming it would break every existing clone and checkout for a cosmetic gain.

## Consequences

- One inventory, one comparison, one operation set covers both kinds; adding a third kind would follow the same pattern and would need only a new `kind` value plus its install root.
- A manifest that omits `kind` no longer parses, so a hand-edited entry fails loudly instead of being silently mis-compared as a skill. Bookkeeping always writes `kind`.
- `manifestVersion` 2 is not readable by a v1 reader: `installRoot` → `skillInstallRoot`, `skills` → `entries`, and `kind` is now required. The manifest and the only two programs that read it ship in the same repo and move in the same commit, so nothing is stranded — but `skill-version-check` took a major bump to 2.0.0 for the renamed flags and the changed manifest input.
- The JSON report follows the same vocabulary: `skillInstallRoot`, an `entries` array, and `Name` in both the entry rows and the orphan rows.
- A leaf holding both `SKILL.md` and `AGENT.md` is an error ("one name, one kind"), because a single manifest entry cannot describe two install layouts.
- Converting an entry's kind is a major version bump ([0003](0003-version-bumps-ride-in-the-content-commit.md)) and leaves a dispatching orphan at the old path, which is what forced the `superseded` exception in [0006](0006-orphans-are-reported-not-deleted-except-superseded.md).
- The agents install root cannot be pruned, so an agent removed from the repo stays installed until the user deletes it by hand.
- Post-Sync verification of an agent is weaker than for a skill: the file is on disk but inert until the next session, so "installed" and "in effect" are no longer the same moment. This is the one place the two kinds are genuinely not peers.
- The manifest file name and the skill's own name still say "skill" while both cover agents too — accepted as a naming cost in exchange for stable paths and a stable dispatch trigger.

## Alternatives considered

- **Make `kind` optional, absent meaning `skill`.** Backward compatible with the v1 manifest and a smaller diff — no entry rewrites, no key renames. Rejected: it makes skill the privileged kind, leaves every unqualified name (`installRoot`, `skills`, the `Skill` column) meaning "skill", and turns a forgotten `kind` into a silent misread rather than an error.
- **Rename `skills-manifest.json` to `manifest.json`.** Consistent with the rest of the renaming, but it is the repo-root discovery anchor referenced by both scripts, the root `CLAUDE.md`, the README, and every ADR; the churn buys nothing the in-file key names do not already buy.
- **A separate `agents-manifest.json`.** Two inventories, two comparisons, two drift sections, and a duplicated orphan pass — every shared rule would have to be stated twice and kept in sync, on top of the two script ports that already need hand-syncing ([0005](0005-comparison-ships-as-two-hand-synced-script-ports.md)).

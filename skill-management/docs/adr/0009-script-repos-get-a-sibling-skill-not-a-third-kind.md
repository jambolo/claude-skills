# 0009. Bash-script repos get a sibling skill (`script-version-check`) over the same manifest model, not a third kind

**Status:** Accepted
**Date:** 2026-08-25
**Commits:** ea969b0

## Context

By 5cde06f the versioning model — a version line in each owned file, a root manifest mirroring it, drift as an error, a comparison script in two ports, refresh-first Sync — worked for this repo's skills and agents ([0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md)–[0007](0007-agents-share-the-manifest-via-a-kind-discriminator.md)). The same problem exists for repos of standalone bash scripts (e.g. `jambolo/git-helpers`) installed by copying files to `~/bin`, but three things differ: the repo is not this one, a bash file has no frontmatter, and `~/bin` is a directory the repo does not own in any sense.

ea969b0 ("Added new script-version-check skill. Renamed skills-manifest.json to manifest.json.") added a second skill rather than teaching `skill-version-check` about scripts. `skill-management/CLAUDE.md` describes it as:

> `script-version-check` is the same idea pointed at repos of standalone bash scripts … The target repo is whatever folder holds `manifest.json` (found by walking up from the cwd — there is no hardcoded upstream; Refresh pulls `--ff-only` from the repo's own `origin`, whatever it is, and never adds or rewrites a remote). Every manifest entry has `"kind": "script"` — the only kind; anything else aborts. A script's version lives in a `# version: x.y.z` comment within the first 15 lines (by convention directly under the shebang), since bash has no frontmatter. Sync copies single files repo → `~/bin/<name>` (`install -m 0755`); `~/bin` is not owned by the repo, so the skill never enumerates, mirrors, or deletes there and there is no orphan section.

The same commit renamed this repo's manifest from `skills-manifest.json` to `manifest.json`, so one filename is the repo-root marker for both skills, and bumped `skill-version-check` to 3.0.0 for the change.

## Decision

Version bookkeeping for script repos is a separate skill with its own pair of comparison scripts (`Compare-ScriptVersions.ps1`, `compare-script-versions.sh`), built on the same model as `skill-version-check`: same operations (Refresh, Check, Sync, Bookkeeping), same statuses, same drift rule, same two-port discipline ([0005](0005-comparison-ships-as-two-hand-synced-script-ports.md)). It differs only where the target does:

- **The repo is found, not named.** The nearest ancestor holding `manifest.json` is the target; Refresh pulls fast-forward-only from that repo's own `origin` and never adds or rewrites a remote.
- **The version is a header comment**, `# version: x.y.z` within the first 15 lines.
- **`kind` is still mandatory** and has exactly one legal value, `script`; a missing or different kind aborts the whole manifest.
- **`~/bin` is never enumerated or mirrored.** The only writes are single-file copies of confirmed entries, so there is no report of unowned installs.

The manifest filename is `manifest.json` in every repo either skill manages.

## Rationale

- The skills are separate because the processes differ: locating the repo, reading a version, and installing are each done differently for scripts than for skills and agents (the differences listed under Decision).
- The manifest was renamed because its function is the same in both cases while the targets are different, so the name should describe the function and not one kind of target.

## Consequences

- There are four comparison scripts to keep in step: each skill's two ports with each other, and — by convention, not enforcement — the two skills' shared behavior with each other. A fix to shared logic lands in all four (c262cb3 is the first example).
- A manifest's `kind` values decide which skill it belongs to; each skill refuses a manifest containing the other's kinds, so pointing the wrong skill at a repo fails loudly instead of installing into the wrong root.
- `skill-version-check` keeps its hardcoded upstream and its two install roots; `script-version-check` has neither, so it works on any script repo that adopts the manifest shape and the header comment.
- The rename broke anything that referenced `skills-manifest.json`; [0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md) and the ADRs after it use the old name where they describe the state at the time.
- The original "never delete anything in `~/bin`" rule was narrowed by [0010](0010-removals-are-tombstones-in-the-manifest.md) to allow confirmed deletion of tombstoned names.

## Alternatives considered

- **A third kind, `script`, inside `skill-version-check`**: not taken, because the process for scripts differs from the process for skills and agents.
- **Keep `skills-manifest.json` here and use a different name for script repos**: not taken; the file does the same job in both, so it has the same name.

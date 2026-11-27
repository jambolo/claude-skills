# 0010. A removal is a tombstone in the manifest's `removed` array, so Sync can offer to delete the installed copy

**Status:** Accepted
**Date:** 2026-11-10
**Commits:** 9b1b81c

## Context

[0008](0008-unowned-installs-are-ignored-except-superseded.md) made everything the manifest does not mention invisible to the scripts. That is right for other people's skills, but it has a hole: when a skill, agent, or script is deleted from the repo and its entry dropped, its installed copy becomes exactly such an unmentioned item. It is never reported, never removed, and — for a skill or agent — keeps dispatching; for a script it keeps resolving from `PATH`. The repo had no way to say "this used to be mine and should go".

9b1b81c ("removed skills and scripts are marked as such (rather than just removing the entry) so that a sync will remove them") added a top-level `removed` array to the manifest and a rule to the root `CLAUDE.md`:

> Do not just delete the leaf. In the same commit, drop its manifest entry and add a tombstone to the manifest's top-level `removed` array (`{ "name", "kind", "removed": "<YYYY-MM-DD>" }`) so `skill-version-check` can offer to delete the installed copy … Keep tombstones; never regenerate the manifest without carrying `removed` over.

Both skills gained the behavior. In `skill-version-check` the **Superseded leftovers** section became **Leftovers**, with `skill (removed)` / `agent (removed)` rows beside the `superseded` ones. In `script-version-check`, which until then never deleted anything in `~/bin`, a **Removed leftovers** section lists "each regular file at `~/bin/<name>` whose name the manifest's `removed` array tombstones (and that is not a live entry again). Nothing else in `~/bin` is ever listed."

## Decision

Removing an owned item is recorded, not just performed. In the commit that deletes the leaf (or script), its `entries` row is dropped and a tombstone `{ "name", "kind", "removed": "<YYYY-MM-DD>" }` is added to the manifest's optional top-level `removed` array. `kind` is mandatory in a tombstone and decides where Check looks (`<skillInstallRoot>/<name>/`, `<agentInstallRoot>/<name>.md`, or `~/bin/<name>`). Check reports an installed item matching a tombstone as a `removed` leftover; Sync offers to delete it, listing name and path, and deletes exactly the reported paths only with the user's confirmation. Declining is accepted with a warning that the obsolete item is still live.

Tombstones are kept indefinitely and dropped only when the name is reused by a live entry of the same kind. Regenerating the manifest carries `removed` over unchanged, because it is the one part of the manifest that cannot be derived from the repo.

## Rationale

- "So that a sync will remove them" (commit message) — "installed copies would linger forever, because the scripts ignore anything the manifest does not mention" (`SKILL.md`).
- Tombstones are kept because "it is cheap, and an old install may surface at any time", and `removed` must be carried over on regeneration because "it cannot be derived from the repo, since the leaves are gone."

## Consequences

- The set of things the skills may delete is still name-derived and closed: `superseded` ([0006](0006-orphans-are-reported-not-deleted-except-superseded.md), [0008](0008-unowned-installs-are-ignored-except-superseded.md)) and now `removed`. Items that are neither an entry nor a tombstone remain invisible.
- `script-version-check`'s rule for `~/bin` narrows from "never delete" to "delete only a confirmed, tombstoned filename"; it still never enumerates the directory.
- The manifest is no longer a pure projection of frontmatter ([0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md)): `removed` is hand-maintained state, and the Bookkeeping "regenerate" operation has to preserve it. Losing it silently reintroduces the hole.
- Removal joins version bumps as a same-commit obligation ([0003](0003-version-bumps-ride-in-the-content-commit.md)) and is stated in the root `CLAUDE.md` because it binds every family.
- All four comparison scripts parse `removed` (with and without `jq`) and must agree on the section and markers; shipped as minor bumps (`skill-version-check` 4.1.0, `script-version-check` 1.1.0) since the array is optional and existing manifests are unaffected.
- A tombstone naming something a user installed independently under the same name would be offered for deletion; the confirmation step is the only guard.

## Alternatives considered

- **Just delete the entry** (the behavior before 9b1b81c): installed copies linger forever, by construction of 0008.
- **Go back to reporting every unowned install** (0006) so stale copies show up: reintroduces the noise 0008 removed and still cannot tell "was ours" from "never ours".

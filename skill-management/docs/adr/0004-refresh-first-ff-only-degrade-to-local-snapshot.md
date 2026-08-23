# 0004. Every operation starts with a fast-forward-only pull from a verified upstream, and degrades to the local snapshot on failure

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca

## Context

The manifest is only authoritative if the clone holding it is current. 7f7a7ca made refreshing the clone a mandatory first step of every operation rather than a user-invoked prelude:

> The repo is `jambolo/claude-skills` on GitHub, and it is refreshed from there before any comparison — a check against a stale clone reports stale answers.

and, in the operations table: "**Refresh runs first every time**, whichever operation follows", reinforced by "Never skip this because the clone 'looks current'."

Refresh operates on the user's working repo, which may hold uncommitted authoring work — this is the same folder skills are edited in. Three constraints follow. First, the remote is verified before anything is fetched, and a mismatch stops the operation outright:

> It must be `jambolo/claude-skills` in either form … If it points somewhere else, or the folder is not a git repo, **stop and report** — do not pull, and do not add or rewrite a remote.

Second, the pull is non-destructive by construction:

> **Pull, fast-forward only.** Never rebase, merge, stash, reset, or discard local work to make the pull succeed

Third — the non-obvious part — a failed pull does not abort the operation. Each of divergence, blocked-by-local-modifications, and fetch failure resolves to "continue against the local snapshot", paired with a disclosure obligation:

> In every case except a clean pull, **say in the final report that the comparison ran against a possibly stale clone**, and why.

Repo-root resolution is bounded the same way — current directory or nearest ancestor holding `skills-manifest.json`, then one known path, then ask; "Never guess a third location." The section closes by scoping the blast radius: "Nothing here touches the install root. Refresh only updates the repo."

## Decision

Refresh runs before Check, Sync, and Bookkeeping, every time. It verifies `origin` is `jambolo/claude-skills` and stops without pulling if it is not; it never adds or rewrites a remote. It pulls `--ff-only` and never rebases, merges, stashes, resets, or discards to make the pull succeed. Any outcome other than a clean pull is reported and the operation continues against the local snapshot, with the report stating that the answer may be stale and why. Refresh writes only to the repo, never to an install root.

## Consequences

- A stale or offline answer is still an answer, and is labeled as one — the skill stays usable on a plane or behind a blocked auth prompt.
- Divergence and dirty working trees are the user's to resolve; the skill will not "fix" them, so authoring work in progress is never at risk from running a version check.
- Sync inherits a second gate from this: if Refresh could not reach upstream, Sync asks for confirmation before installing, "you would be copying a clone of unknown freshness into the install root."
- Pinning one upstream means a fork cannot be driven by this skill without editing it.
- Only the checked-out branch is pulled, and a non-default branch is called out, since "skill versions are tracked on the default branch."

## Alternatives considered

None recorded.

# 0003. All work lands on one local working branch, and the supervisor creates every worktree itself at an exact base

**Status:** Accepted
**Date:** 2026-07-04
**Commits:** 106acf1, 5039ccd

## Context

The first supervisor (e3ff846) launched each parallel worker with the Agent tool's `isolation: "worktree"` option and assumed "worktrees branch from the current HEAD". They did not. 106acf1 ("Fixed a problem where a worker's worktree was based on the wrong commit") records what happened instead:

> That mode bases its worktree on the remote default branch (`origin/HEAD`), not your session HEAD — so every local-only commit, i.e. the pipeline's entire accumulated work, is absent — and it picks opaque `agent-<id>` paths and branches you can neither verify, merge, nor clean up deterministically.

A worker handed a stale base tried to repair it by fetching or cherry-picking sibling work, which corrupts the scope check of [0002](0002-supervisor-verifies-against-ground-truth.md).

## Decision

An "Integration model" paragraph was added to the Shared model:

> All pipeline work accumulates as commits on one dedicated **local working branch**, recorded (with its starting commit) in the ledger's Plan section. … Every worker worktree must be based on that branch's **current local HEAD** — never on a remote or default ref such as `origin/HEAD`. The supervisor creates and verifies all worktrees itself.

Concretely:

- The planner seeds `working-branch`, `starting-commit`, and `default-branch` in the ledger "from the actual repo, never from assumption".
- Per wave, the supervisor records `BASE` = the working branch's HEAD and creates `wt/<plan-name>-<id>` worktrees at `BASE`, outside the main working tree, immediately before launch. `isolation: "worktree"` is never used.
- A base gate runs before launch: each worktree's HEAD must equal `BASE` and every dependency's ledger commit must be an ancestor of it. "This check must hold no matter how a worktree came to exist."
- Workers are ordinary subagents given the worktree's absolute path and a path-discipline contract (absolute paths, `git -C <worktree>`).
- A step with `depends_on` opens by asserting a concrete artifact of each dependency and stops with a "missing base" report if it is absent — "a worker must detect a wrong or stale base, never repair one".
- Worktrees and their `wt/` branches are removed after every step, pass or fail.

## Rationale

- `isolation: "worktree"` starts from `origin/HEAD`, so the pipeline's own unpushed commits are missing, and its paths and branches cannot be verified, merged, or cleaned up deterministically (106acf1).
- The worker-side assertion "makes every worker an independent detector of a mis-based worktree, defense-in-depth behind the supervisor's own gate".
- The gate is "mechanism-agnostic" because "it is what catches a harness or tooling regression".

## Consequences

- The working branch is usually unpushed and need not be the default branch; nothing in the pipeline pushes.
- A worker's shell starts in the main repo, so staying inside the worktree depends on the contract's path discipline, not on isolation by the harness.
- Fresh worktrees have no installed dependencies; the supervisor confirms the toolchain runs in one before a phase's first wave, and "workers must never improvise setup".
- Since 5039ccd, worktree creation and the base gate are `wave-create.sh` ([0013](0013-deterministic-mechanics-are-pipeline-tools-scripts.md)).
- The base of `isolation: worktree` is a documented harness default (`worktree.baseRef`), not a constant; the family `CLAUDE.md` lists it among the facts to re-check after a Claude Code upgrade.

## Alternatives considered

- **`isolation: "worktree"`** (e3ff846): the defect this ADR fixes.
- **Let a worker repair a stale base** (fetch, merge, cherry-pick): forbidden; it puts foreign commits in the step's diff.

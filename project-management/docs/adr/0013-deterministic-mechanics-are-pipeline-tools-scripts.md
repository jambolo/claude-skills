# 0013. The pipeline's deterministic mechanics are bash scripts in a `pipeline-tools` skill, and the artifact fields they read are a parsed schema

**Status:** Accepted
**Date:** 2026-10-22
**Commits:** 5039ccd

## Context

Until 5039ccd the supervisor carried out worktree creation, the base gate, step verification, merging, ledger updates, and Definition of Done checks by composing git and shell commands from prose instructions ([0002](0002-supervisor-verifies-against-ground-truth.md), [0003](0003-supervisor-creates-worktrees-at-an-exact-base.md)). A review of the whole pipeline (`Project-Management Pipeline Review 2026-10-22.pdf`, 6bed64e) covered "effectiveness and efficiency findings, implementation and architecture improvements, and cost evaluation methods", and 5039ccd ("applied pipeline review recommendations") moved those mechanics out of the prompts. The Shared model gained:

> **Scripts.** The deterministic mechanics — worktree creation with base gates, step verification, merge and ledger recording, Definition of Done runs, formatter-gate detection — are bash scripts in the `pipeline-tools` skill, installed at `$HOME/.claude/skills/pipeline-tools/scripts/`. … Every script prints its verdict or record lines first and exits non-zero on failure; act on those lines, never on a re-run of the git commands they replace.

## Decision

- Five scripts carry the mechanics: `wave-create.sh` (worktrees at BASE with the dependency gate), `step-verify.sh` (one commit, scope, acceptance), `step-merge.sh` (merge, ledger row, commit, cleanup), `dod-run.sh` (a `dod` block), and `find-formatter-gates.sh`. Agents call them by path and act on the verdict lines. Exit codes are fixed: 0 success, 1 verdict failure, 2 usage or unparsable input.
- They ship in a new skill leaf, `pipeline-tools`, with fixtures (`smoke`, `smoke-undecomposed`, `mid`, `project`), a no-model `selftest.sh`, and a benchmark harness (`bench-run.sh`, `bench-summary.sh`). An agent that finds the scripts directory missing returns `RESULT: failed` naming the path.
- The fields the scripts read are a schema, not prose:
  - a step's `acceptance` became `acceptance_cmd` and `acceptance_expect` (exact stdout, or the single line `exit 0`), with fixed indentation, beside `files_in_scope`;
  - every Definition of Done — the brief's and each roadmap phase's — is a fenced block tagged `dod`, one record per item (`cmd:` and `expect:`, or `manual:` for what only a person can confirm);
  - the ledger's Steps columns are rewritten by `step-merge.sh`.
- The worker reads its step file itself, so the supervisor's packet shrank to five lines (worktree, plan-name, id, artifacts-dir, step-file).

## Rationale

- Scripts for mechanistic tasks avoid token usage: an agent spends tokens on a script's verdict lines, not on composing and reading the git commands behind them.
- `pipeline-tools` is a skill, though it has almost no operation of its own, "because a skill leaf can carry `scripts/` and a fixture and installs at a path the agents can name" (family `CLAUDE.md`).

## Consequences

- The agents now have an install-time dependency on a skill; `skill-version-check` installs both.
- "Change the schema and the scripts together, and run `selftest.sh`" (family `CLAUDE.md`). A change to a step field, the ledger columns, or the `dod` format is a major bump of the affected agents.
- The mechanics are testable without a model or spend: `selftest.sh` exercises every script with a bash-simulated worker, and the smoke fixture exercises the agents end to end for cents.
- All five stage leaves took major bumps (planner 4.0.2, decomposer 4.1.0, supervisor 4.1.1, worker 3.0.0, lead-developer 3.0.2).
- `manual:` items print `MANUAL` and never fail a run, so a Definition of Done can name what a script cannot check without blocking on it.
- The scripts are bash; on Windows they need Git Bash, and `.gitattributes` pins `*.sh` to LF.

## Alternatives considered

- **Keep the mechanics as prose the supervisor executes** (e3ff846 through 3a67c8b): the model spent tokens re-deriving the same git sequence for every step.
- **Ship the scripts inside each agent**: not possible; an agent installs as a single file (`~/.claude/agents/<name>.md`), which is why the scripts live in a skill leaf.

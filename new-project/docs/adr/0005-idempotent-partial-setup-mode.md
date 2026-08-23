# 0005. Every scaffolder is idempotent and finishes a partially set-up project

**Status:** Accepted
**Date:** 2026-07-09
**Commits:** ba697a6, c5577ac

## Context

The first-pass skills assumed an empty target: `mkdir <project name>` (fails if present), `cargo new` (refuses an existing folder), PkgTemplates ("refuses to generate into an existing non-empty path"), and LICENSE/README written unconditionally. ba697a6 added the second mode to every skill, its description ("Also finishes a partially set-up Rust project, adding only what's missing … or to complete/fill in the setup of an existing one"), and the family contract:

> Idempotent / partial-setup aware: each skill has a "Partially set-up projects" section — existing artifacts are kept (`.gitignore` is merged by appending missing entries), generation is skipped when the language manifest already exists, and a step is committed only if it changed something.

The per-skill section has the same shape everywhere:

> - If `Cargo.toml` already exists, skip cargo generation entirely …
> - If the repo already has commits, skip the "New repo" empty commit.
> - An artifact that already exists (LICENSE, README, a workflow file) is kept as-is, not overwritten; skip that step and its commit.
> - `.gitignore` is merged, not replaced: append only the missing entries (including `.vscode/`).
> - Only commit a step that actually changed something, keeping the same commit messages.

and the steps were adjusted to make it possible: `mkdir -p`, `cargo init` in place when the folder exists, `npx gitignore` relied on because it "appends to an existing file, so nothing is lost", `rmdir` of an *empty* pre-created folder before PkgTemplates. Julia, whose generator cannot run in place, has the one hard stop: "If the folder is non-empty but has no `Project.toml`, stop and ask the user how to proceed." c5577ac extended the rules to multi-file state (workspace `members`, crate directories, icons, `package.json` fields).

## Decision

Each scaffolder is a set of idempotent steps. Before each step it checks whether the step's output exists: a present manifest skips generation, a present artifact is kept untouched, `.gitignore` is merged by appending missing entries, the empty "New repo" commit is skipped when history exists, and a step is committed — under the standard message — only if it changed something. A scaffolder therefore both creates a project and completes one, and its description triggers on both phrasings. The final report lists the steps that were skipped.

## Consequences

- Running a scaffolder twice is a no-op; running it over a hand-started repo yields the same end state and commit messages as a fresh scaffold minus the steps already done.
- Every step must have a detectable "already done" condition, which constrains how steps are written (one artifact per step, files rather than in-memory state).
- "Keep as-is" means a stale or wrong existing artifact is not repaired — the mode adds, it never overwrites.
- `advent-of-code` can delegate to a scaffolder after creating the directory itself, and can re-run it safely.
- Language generators that refuse existing paths (PkgTemplates) force a language-specific branch and, in one case, a question to the user — the only non-autonomous path in the family.

## Alternatives considered

None recorded beyond the initial fail-on-existing behavior that this decision replaced.

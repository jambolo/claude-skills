# 0004. Plan artifacts are committed on the working branch as the plan proceeds

**Status:** Accepted
**Date:** 2026-07-04
**Commits:** 106acf1, 61ac934, fbc90c0

## Context

In e3ff846 the brief, roadmap, ledger, and step files were written to disk and left there; only workers' code changes were committed. 106acf1 ("Project management skills now commit plan artifacts as the plan proceeds") made every stage end with a commit. The decomposer's text gives the reason:

> Plan state is versioned like everything else: the supervisor merges worker commits into this same branch, and the revision loop relies on history for which version of a step a worker actually ran against.

> The superseded version must stay reachable in history; never leave a revision sitting uncommitted in the working tree.

## Decision

Each stage commits its artifacts on the working branch before it hands off, with a fixed message:

- planner: `plan(<plan-name>): brief, roadmap, ledger` (and `amend(<plan-name>): <what>` for an amendment);
- decomposer: `decompose(<plan-name>): phase <N> steps` and `decompose(<plan-name>): revise phase <N>`;
- supervisor: `merge(<plan-name>): step <id>`, `supervise(<plan-name>): record step <id>`, and `supervise(<plan-name>): phase <N> complete`.

61ac934 (R4) tightened this to the ledger being "committed per step and before any in-tree launch; clean tree required", and (R10) recorded `artifacts-dir` in the ledger so all stages resolve artifact paths from one place. fbc90c0 (finding 9) pinned the commit-message formats for worker, merge, and supervisor commits.

## Rationale

- "The revision loop relies on history for which version of a step a worker actually ran against."
- "An emit that never lands in history can't be audited or revised against."

## Consequences

- The working branch interleaves plan commits with code commits; a consumer who wants only the code has to squash. The `lead-developer` skill does exactly that per milestone ([0009](0009-lead-developer-drives-the-pipeline-per-milestone.md)).
- A clean working tree is a precondition for launching a wave, so a dirty tree is an error to report, not a state to work around.
- Pinned message formats make the history machine-readable: a run can be reconstructed from `git log` alone.
- Because artifacts are committed, any repo gate that formats or lints committed Markdown now applies to them ([0011](0011-artifacts-are-excluded-from-formatter-gates.md)).

## Alternatives considered

- **Leave artifacts uncommitted until the end** (e3ff846): a revised step overwrote the version a worker had run against, with no record.
- **Commit only at phase completion**: superseded by R4; the ledger must be committed per step so an interrupted run resumes from a truthful state.

# 0008. Scaffold commit messages are exactly the ones the skill gives: no attribution trailers

**Status:** Accepted
**Date:** 2026-10-16
**Commits:** 3a67c8b

## Context

Every scaffolder seeds the new repo with one commit per setup step ("New repo", "Added .gitignore", "Added MIT License", …), and `new-project/CLAUDE.md` calls that history "intentional output, not incidental". The messages are also load-bearing for the partial-setup mode ([0005](0005-idempotent-partial-setup-mode.md)), which commits a step only if it changed something, "keeping the same commit messages".

The skills run inside a Claude Code session, whose default commit guidance appends a `Co-Authored-By:` trailer to every commit it makes. Nothing in the skills said otherwise, so a scaffolded repo's seeded history carried an attribution line on each commit, although their content is boilerplate. 3a67c8b ("new-project: Removed Claude attribution in commit messages") added the same paragraph at the top of "Steps" in all six skills:

> **Commit messages are exactly the messages given below.** Never append a `Co-Authored-By:` trailer (or any other attribution line), even if the environment's default commit guidance says to.

## Decision

A scaffolder's commit messages are part of its specified output. Each commit carries exactly the message the skill gives for that step and nothing else: no `Co-Authored-By:` trailer and no other attribution line. The skill's instruction explicitly overrides the session's default commit guidance, and the rule is stated once per skill, ahead of the steps, rather than on each commit command.

## Rationale

The scaffolded work is mostly boilerplate — a generated `.gitignore`, a license, a starter README, copied templates — and needs no special attribution.

## Consequences

- The seeded history of a scaffolded repo is identical whether the skill is run by a person following it by hand or by a session, and identical across harness versions whose default attribution text differs.
- Every skill in the family must carry the paragraph; a new scaffolder that omits it silently regains the trailer. The six skills were patch-bumped together for this (`1.0.0` → `1.0.1`; `new-cpp-project` → `1.0.2`).
- The override is scoped to the scaffold's seeded commits. It says nothing about commits made in the scaffolded repo afterwards, which follow that repo's own conventions.
- `advent-of-code` scaffolds inherit the behavior through delegation to these skills.

## Alternatives considered

- **Leave it to the environment's default** (every commit before 3a67c8b): every seeded commit carried an attribution line that boilerplate does not warrant.

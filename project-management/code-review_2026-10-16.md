# Ultrareview: bc9f869..ab8453e

Oct 16, 2026 · @Claudius Gallus

A cloud ultrareview of the five commits after bc9f869 (af9f8fd through ab8453e; 13 files, +155/−93) found 9 issues: 3 normal, 5 nits and 1 pre-existing. Six come from af9f8fd, which added formatter exclusions for pipeline artifacts. The findings are as the review reported them and have not been checked against the code.

## Findings

Three normal findings need fixes before the formatter-exclusion change works as intended; the rest are nits and one gap the review marked pre-existing.

| # | Severity | Commit | Location | Finding | Suggested fix |
| --- | --- | --- | --- | --- | --- |
| 1 | Normal | `af9f8fd` | `project-management/lead-developer/SKILL.md:213`, `project-management/planner/AGENT.md:293` | The skill gives the glob `<artifacts-dir>/<name>-*.md` for pre-commit `exclude:`, which is a Python regex. It matches no artifact, so hooks keep rewriting them while the agents report the exclusion as added. | Use a regex for pre-commit at both sites, e.g. `^<artifacts-dir>/<name>-.*\.md$`. |
| 2 | Normal | `af9f8fd` | `project-management/lead-developer/SKILL.md:206-219` | The plan operation edits tracked ignore files in §5, then checks out `develop` in §6. Tool detection reads the wrong branch, and the uncommitted edits can make `git checkout develop` fail. | Check out `develop` before §5. |
| 3 | Normal | `af9f8fd` | `project-management/lead-developer/SKILL.md:214`, `project-management/planner/AGENT.md:294` | markdownlint-cli2 (pre-commit hook, GitHub action, VS Code extension) never reads `.markdownlintignore`. The artifacts are reported as excluded while `--fix` still rewrites them. | Use the mechanism each detected tool reads, e.g. `ignores` in `.markdownlint-cli2.*`. |
| 4 | Nit | `af9f8fd` | `project-management/planner/AGENT.md:287-297` | Planner §6 is labeled a fallback but always runs. If the user accepted an unrecognized gate during planning, the planner returns `needs-human` on every milestone, so the project never executes. | Skip §6 when lead-developer already handled exclusions, e.g. via the project ledger or a prompt flag. |
| 5 | Nit | `af9f8fd` | `project-management/planner/AGENT.md:295-297` | The §6 `needs-human` exit fires after §3-5 wrote the brief, roadmap and ledger, and possibly after some ignore edits. It leaves a dirty tree that execute refuses; every other planner `needs-human` writes nothing. | Survey formatter gates before §3, or revert the writes before returning `needs-human`. |
| 6 | Nit | `428dcd8` | `README.md:19-20` | README still lists planner and decomposer as "Fable / max"; both now pin `opus`. | Update the bullets: planner Opus / high, decomposer Opus / xhigh. |
| 7 | Nit | `66dbede` | `manifest.json:107` | skill-version-check went 3.0.0 → 3.1.0, but its output format changed: a report header was renamed and the `--json` `orphans` array drops rows. Root CLAUDE.md makes a format change a major bump. | Make it a major bump (4.0.0) in `SKILL.md` and the manifest. |
| 8 | Nit | `66dbede` | `skill-management/skill-version-check/SKILL.md:167-174` | ADR 0006 and its index row (`docs/adr/README.md:14`) still say unowned installs are reported. The scripts no longer report them, and no ADR supersedes 0006. | Add a superseding ADR, or mark 0006 amended and update the index. |
| 9 | Pre-existing | `af9f8fd` | `project-management/worker/AGENT.md:117-120` | The worker must not let a pre-commit hook rewrite its report, but has no instruction for when one does. It can only return done or failed, so the supervisor spends retries and a revision; a cheap worker may commit the rewritten report. | Tell the worker never to re-stage a rewritten report or use `--no-verify`, but to record it and return a distinct status the supervisor routes straight to `needs-human`. |

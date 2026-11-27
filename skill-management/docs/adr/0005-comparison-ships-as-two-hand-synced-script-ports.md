# 0005. The comparison ships as a bundled script, in two hand-kept-in-sync ports

**Status:** Accepted
**Date:** 2026-08-21
**Commits:** 7f7a7ca, 5cde06f, ea969b0, c262cb3

## Context

Every other skill in this repo is instruction-only — prose the model follows. 7f7a7ca broke that pattern for the version comparison alone, shipping `scripts/Compare-SkillVersions.ps1` (146 lines) and `scripts/compare-skill-versions.sh` (293 lines) inside the skill leaf. The comparison is mechanical, exhaustive over the whole manifest, and its output is the input to a destructive operation, so having a model re-derive it per invocation buys nothing and risks a wrong row.

Two ports rather than one, because the repo's own guidance is PowerShell-first on Windows while the skill has to run under bash, Git Bash, and WSL too. The `SKILL.md` is explicit that they are interchangeable:

> The two are ports of each other — same statuses, same sections, same summary line — so pick by shell, not by preference.

The family `CLAUDE.md` states the maintenance obligation and the two portability constraints that keep the bash port usable where `jq` and gawk are not:

> They are ports of each other: same six statuses, same `Kind` column, same drift and orphan sections (including the `superseded` marker), same `Summary:` line. **An edit to one must be mirrored in the other.** The bash port deliberately works without `jq` (built-in manifest scanner as fallback) and without gawk-only features, so keep it that way. `*.sh` files are pinned to LF via `.gitattributes` so a Windows checkout cannot ship CRLF into a shebang.

The `jq` fallback is a 25-line awk manifest scanner carrying its own scope note — "it assumes entry objects contain no nested objects or arrays, which the manifest schema guarantees" — which is a direct dependency on the flat manifest shape from [0001](0001-semver-in-frontmatter-mirrored-by-a-root-manifest.md). Both ports also offer `-Json` / `--json` so the result can be consumed programmatically instead of scraped from the table. 5cde06f edited both ports together, adding the `Kind` column and the agent layout branch to each.

## Decision

The manifest-vs-installed comparison is implemented as a bundled script, not as prose instructions. It exists as two ports — PowerShell and bash — that are behaviorally identical: same six statuses, same `Kind` column, same drift and orphan sections, same `Summary:` line, same `--json` shape. An edit to one is mirrored in the other in the same commit. The bash port depends only on `bash`, `awk`, `grep`, `find`, and `sed`, uses `jq` when present and a built-in scanner when not, and avoids gawk-only features. `*.sh` is pinned to LF in `.gitattributes`.

## Consequences

- Every comparison is deterministic and complete over the manifest; the model's job is narrowed to reading the table and deciding what to do about it.
- Two implementations of one algorithm must be kept in step by hand, and the family `CLAUDE.md` carries that obligation explicitly because nothing enforces it.
- The awk fallback parser is coupled to the manifest staying a flat array of flat objects — nesting an entry would silently break the no-`jq` path while the `jq` path keeps working.
- `skill-version-check` is the only leaf in the repo with a `scripts/` directory, which is why Sync must mirror the whole leaf folder and preserve the `+x` bit rather than copying `SKILL.md` alone.
- The LF pin exists because the authoring machine is Windows; without it a checkout would ship `#!/usr/bin/env bash\r` and fail on every POSIX host.
- Since ea969b0 the same two-port arrangement is repeated in `script-version-check` ([0009](0009-script-repos-get-a-sibling-skill-not-a-third-kind.md)), so the "only leaf with a `scripts/` directory" statement above describes the state before that commit, and shared fixes land in four scripts.
- The LF pin covers the scripts' own bytes, not their inputs: c262cb3 fixed both bash ports to strip `\r` from `jq` output, because the native Windows `jq.exe` ends lines with `\r\n` and the stray `\r` ended up in the last field (`kind`), failing the kind check. The bash ports have to tolerate CRLF from tools they call when run under Git Bash on Windows.

## Alternatives considered

None recorded.

# CLAUDE.md — `skill-management` family

Guidance for the `skill-version-check` skill. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The skill

`skill-version-check` keeps the installed skills under `~/.claude/skills/` in step with this repo. It first refreshes the local clone from upstream `jambolo/claude-skills` (`git pull --ff-only` only — it never rebases, stashes, or discards; a blocked or unreachable pull is reported and the comparison continues against the local snapshot), then compares `skills-manifest.json` against the installed versions, and optionally mirrors repo → install root. It never copies install root → repo, and it never touches plugin skills under `~/.claude/plugins/`.

## Two script ports, kept in sync

The comparison logic exists twice — `scripts/Compare-SkillVersions.ps1` (`-RepoRoot`, `-InstallRoot`, `-Json`) and `scripts/compare-skill-versions.sh` (`--repo-root`, `--install-root`, `--json`). They are ports of each other: same six statuses, same drift and orphan sections, same `Summary:` line. **An edit to one must be mirrored in the other.** The bash port deliberately works without `jq` (built-in manifest scanner as fallback) and without gawk-only features, so keep it that way. `*.sh` files are pinned to LF via `.gitattributes` so a Windows checkout cannot ship CRLF into a shebang.

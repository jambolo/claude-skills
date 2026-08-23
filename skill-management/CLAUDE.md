# CLAUDE.md — `skill-management` family

Guidance for the `skill-version-check` skill. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The skill

`skill-version-check` keeps the installed skills under `~/.claude/skills/` and agents under `~/.claude/agents/` in step with this repo. It first refreshes the local clone from upstream `jambolo/claude-skills` (`git pull --ff-only` only — it never rebases, stashes, or discards; a blocked or unreachable pull is reported and the comparison continues against the local snapshot), then compares `skills-manifest.json` against the installed versions, and optionally copies repo → install roots (a skill leaf is mirrored as a folder; an agent leaf's `AGENT.md` is copied as the single file `<name>.md` — never mirror the agents folder, it holds agents the repo does not own). Skills and agents are peers: every manifest entry declares `"kind"` as either `"skill"` or `"agent"`, neither is a default, and an entry with a missing or unrecognized `kind` aborts the comparison. An installed orphan whose name matches a manifest entry of the other kind is reported as `superseded` — a leftover of a skill → agent conversion that still dispatches — and may be removed with the user's confirmation. It never copies install root → repo, and it never touches plugin skills under `~/.claude/plugins/`.

## Two script ports, kept in sync

The comparison logic exists twice — `scripts/Compare-SkillVersions.ps1` (`-RepoRoot`, `-SkillInstallRoot`, `-AgentInstallRoot`, `-Json`) and `scripts/compare-skill-versions.sh` (`--repo-root`, `--skill-install-root`, `--agent-install-root`, `--json`). They are ports of each other: same six statuses, same `Name` and `Kind` columns, same drift and orphan sections (including the `superseded` marker), same `Summary:` line. **An edit to one must be mirrored in the other.** The bash port deliberately works without `jq` (built-in manifest scanner as fallback) and without gawk-only features, so keep it that way. `*.sh` files are pinned to LF via `.gitattributes` so a Windows checkout cannot ship CRLF into a shebang.

---
name: skill-version-check
version: 1.2.1
description: >
  Pulls the latest `jambolo/claude-skills` from GitHub, then checks the skill
  versions recorded in that repo's `skills-manifest.json` against the versions
  of the same skills installed locally under `~/.claude/skills/`, and reports
  which local skills are outdated, missing, ahead, or unversioned — and
  optionally installs or updates them. Also keeps the manifest itself honest:
  regenerates it from the repo's `SKILL.md` frontmatter and bumps a skill's
  version after it is edited. Use when the user says things like "check my skill
  versions", "are my skills up to date", "which installed skills are stale",
  "compare the manifest to my installed skills", "sync my skills", "update my
  local skills from the repo", "pull the latest skills", "regenerate the skills
  manifest", or "bump the version of <skill>". Covers only the skills owned by
  this repo plus manifest bookkeeping — it does not author or scaffold skills,
  and it does not touch plugin-provided skills under `~/.claude/plugins/`.
---

# Skill version check

Compare `skills-manifest.json` (the repo's record of the current version of
every skill it owns, including this one) against what is actually installed at
`~/.claude/skills/<name>/`, and reconcile the difference. The repo is
`jambolo/claude-skills` on GitHub, and it is refreshed from there before any
comparison — a check against a stale clone reports stale answers.

## Operations

Pick from the user's phrasing; default to **Check**. **Refresh runs first every
time**, whichever operation follows.

| Operation | Trigger | Effect |
| --- | --- | --- |
| **Refresh** | always, before any of the others | Pull the latest `jambolo/claude-skills` into the local repo root. |
| **Check** | "check skill versions", "am I up to date" | Read-only report. |
| **Sync** | "update/install my skills", "sync skills" | Check, then copy repo → install root for the skills the user confirms. |
| **Bookkeeping** | "regenerate the manifest", "bump <skill>" | Rewrite `skills-manifest.json` from repo frontmatter; bump a skill's `version:` when asked. |

## Paths

- **Upstream** — `https://github.com/jambolo/claude-skills`
  (`git@github.com:jambolo/claude-skills.git` over SSH). The only remote this
  skill pulls from.
- **Repo root** — the folder containing `skills-manifest.json`. Resolve in this
  order: (1) the current working directory or its nearest ancestor holding that
  file; (2) `C:\Users\<user>\Projects\Claude\claude-skills` if it exists;
  (3) ask the user for the path, or offer to clone upstream (Refresh). Never
  guess a third location.
- **Install root** — `$env:USERPROFILE\.claude\skills` on Windows,
  `$HOME/.claude/skills` on Linux/macOS (override only if the user names
  another).
- Plugin skills (`~/.claude/plugins/**`) are out of scope. Do not read, report,
  or modify them.

## Refresh — pull from GitHub

Always bring the local repo up to date with upstream before comparing anything.
Never skip this because the clone "looks current".

1. **Verify the remote.** In the resolved repo root:

   ```bash
   git -C "<repo>" remote get-url origin
   ```

   It must be `jambolo/claude-skills` in either form — `git@github.com:jambolo/claude-skills.git`
   or `https://github.com/jambolo/claude-skills.git` (a trailing `.git` is
   optional). If it points somewhere else, or the folder is not a git repo,
   **stop and report** — do not pull, and do not add or rewrite a remote.
2. **No local clone at all?** Offer to clone it, and only clone where the user
   says:

   ```bash
   git clone https://github.com/jambolo/claude-skills.git "<repo>"
   ```

3. **Pull, fast-forward only.** Never rebase, merge, stash, reset, or discard
   local work to make the pull succeed:

   ```bash
   git -C "<repo>" fetch origin
   git -C "<repo>" pull --ff-only
   ```

4. **Handle the outcomes:**

   | Outcome | What it means | Do |
   | --- | --- | --- |
   | Already up to date | clone matches upstream | continue silently |
   | Fast-forwarded | new upstream commits pulled in | continue; mention how many commits arrived |
   | `--ff-only` refused | local branch has diverged from upstream, or local commits are unpushed | report the divergence and continue against the local snapshot — the user resolves it, not this skill |
   | Pull blocked by local modifications | uncommitted edits would be overwritten | name the files, continue against the local snapshot, never stash or discard |
   | Fetch failed (offline, auth, host down) | upstream unreachable | report the error verbatim and continue against the local snapshot |

   In every case except a clean pull, **say in the final report that the
   comparison ran against a possibly stale clone**, and why.
5. Note the branch — pull only the checked-out branch. If it is not the repo's
   default branch, say so; skill versions are tracked on the default branch.

Nothing here touches the install root. Refresh only updates the repo.

## Check

Run Refresh first, then run the bundled script for the current platform from the
repo root. The two are
ports of each other — same statuses, same sections, same summary line — so pick
by shell, not by preference.

On Windows:

```powershell
& "<repo>\skill-management\skill-version-check\scripts\Compare-SkillVersions.ps1" -RepoRoot "<repo>"
```

On Linux/macOS (also works in Git Bash / WSL):

```bash
bash "<repo>/skill-management/skill-version-check/scripts/compare-skill-versions.sh" --repo-root "<repo>"
```

Add `-Json` / `--json` when you need to consume the result programmatically, or
`-InstallRoot <path>` / `--install-root <path>` for a non-default install
location. Both scripts discover the repo root themselves by walking up from the
current directory, so the root flag is optional when already inside the repo.

The bash port needs only `bash`, `awk`, `grep`, `find`, and `sed`; it uses `jq`
to read the manifest when it is on `PATH` and falls back to a built-in parser
when it is not.

The script prints one row per manifest entry with `Manifest` (version in
`skills-manifest.json`), `Repo` (version in the repo's `SKILL.md`), `Local`
(version in the installed `SKILL.md`), and a status:

| Status | Meaning | Action |
| --- | --- | --- |
| `OK` | local == manifest | none |
| `OUTDATED` | local < manifest | offer to update (Sync) |
| `AHEAD` | local > manifest | local edits never committed back — flag, do not overwrite without asking |
| `MISSING` | no folder at install root | offer to install (Sync) |
| `UNVERSIONED` | installed `SKILL.md` has no `version:` | pre-versioning install; treat as OUTDATED and offer to update |
| `DIFFERENT` | versions not comparable as `Major.Minor.Patch` | report verbatim, do not auto-resolve |

It also prints two secondary sections:

- **Manifest drift** — `Manifest` != `Repo`. The manifest is stale relative to
  the repo; fix with Bookkeeping before trusting any status column.
- **Installed but not in manifest** — folders under the install root this repo
  does not own. Report as informational only; never delete them.

Summarize in prose: how many OK, what is stale, what is missing. Do not restate
the whole table if everything is `OK`.

## Sync

1. Run Check first (which runs Refresh). Refuse to sync while manifest
   drift exists — fix with Bookkeeping, otherwise you would install a version
   the manifest misreports. If Refresh could not reach upstream, say so and get
   confirmation before installing anything: you would be copying a clone of
   unknown freshness into the install root.
2. List exactly what will change (`<name>: 1.0.0 → 1.2.0`, `<name>: install`)
   and get confirmation. `AHEAD` and `DIFFERENT` skills are excluded by default
   — call them out and only include one if the user explicitly says so, since
   overwriting discards local edits that were never committed to the repo.
3. For each confirmed skill, mirror the whole leaf folder — `SKILL.md` plus any
   `templates/`, `reference/`, `scripts/` — deleting install-root files that no
   longer exist in the repo:

   On Windows:

   ```powershell
   robocopy "<repo>\<path>" "<installRoot>\<name>" /MIR /NFL /NDL /NJH /NJS /NP
   ```

   `robocopy` exit codes 0–7 are success; 8+ is a real failure.

   On Linux/macOS (note the trailing slashes — they make `rsync` mirror the
   folder's contents rather than nest it):

   ```bash
   rsync -a --delete "<repo>/<path>/" "<installRoot>/<name>/"
   ```

   Without `rsync`, replace the whole folder instead:
   `rm -rf "<installRoot>/<name>" && cp -a "<repo>/<path>" "<installRoot>/<name>"`.
   Either way, keep the `scripts/*.sh` executable bit intact (`chmod +x`).
4. Re-run Check and report the resulting status.

Only copy repo → install root. Never copy install root → repo; edits belong in
the repo, made as ordinary file edits and committed.

## Bookkeeping — manifest and versions

Run Refresh first here too — regenerating the manifest from a stale clone
reintroduces versions upstream has already moved past.

**Regenerate the manifest.** Walk every `*/*/SKILL.md` under the repo root, read
`name` and `version` from the frontmatter, and rewrite `skills-manifest.json`:

```json
{
  "manifestVersion": 1,
  "updated": "<YYYY-MM-DD>",
  "installRoot": "~/.claude/skills",
  "skills": [
    { "name": "<name>", "version": "<x.y.z>", "path": "<family>/<name>", "family": "<family>" }
  ]
}
```

Rules: `name` must equal the leaf folder name and `path` must be
`<family>/<name>` relative to the repo root, with forward slashes. Entries are
ordered by family, then by name within the family. Every skill in the repo
appears, including this one. A `SKILL.md` with no `version:` is an error —
add `version: 1.0.0` to its frontmatter (directly under `name:`) rather than
omitting it from the manifest.

**Bump a version.** After a skill's content changes:

- **patch** — wording, typos, clarifications that do not change behavior.
- **minor** — new capability or new template, backward compatible.
- **major** — changed operation names, inputs, or artifact formats; anything
  that invalidates how a caller invokes the skill.

Edit `version:` in that skill's `SKILL.md`, then update the same skill's entry
in `skills-manifest.json`. The two must always agree — that is what Check
calls drift. When the `project-management` family's shared "Shared model"
section is edited, bump all three of `planner`, `decomposer`, and `supervisor`
together, since the change lands in all three files.

## Reporting

Lead with the verdict (`all 11 skills up to date`, or `3 outdated, 1 missing`).
Show the table only when something needs attention. Never modify a skill's
content as a side effect of a version check.

Report the Refresh result in one line before the verdict, but only when it was
not a clean no-op: `pulled 4 commits from upstream`, `upstream unreachable —
compared against the local clone from <date>`, `local branch has diverged from
origin/master`. A clone that was already up to date needs no mention.

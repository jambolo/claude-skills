---
name: script-version-check
version: 1.0.0
description: >
  Pulls the latest changes into the bash-script repo in the current folder (the
  nearest ancestor holding `manifest.json`), then checks the script
  versions recorded in that manifest against the versions of the same scripts
  installed in `~/bin`, and reports which installed scripts are outdated,
  missing, ahead, or unversioned — and optionally installs or updates them.
  Also keeps the manifest itself honest: regenerates it from the scripts'
  `# version:` header comments and bumps a script's version after it is
  edited. Use when the user says things like "check my script versions", "are
  my scripts up to date", "which installed scripts are stale", "sync my
  scripts", "update ~/bin from this repo", "install these scripts to ~/bin",
  "regenerate the scripts manifest", or "bump the version of <script>".
  Operates only on repos of standalone bash scripts that carry a
  `manifest.json` (e.g. `git-helpers`) — for the Claude skills and
  agents owned by `jambolo/claude-skills` use `skill-version-check` instead;
  this skill never reads or writes anything under `~/.claude/`.
---

# Script version check

Compare `manifest.json` (a scripts repo's record of the current version
of every bash script it owns) against what is actually installed at
`~/bin/<name>`, and reconcile the difference. Unlike the sibling
`skill-version-check`, this skill is not tied to one upstream — it works on
whatever scripts repo the current directory is in, and it refreshes that repo
from its own `origin` before any comparison — a check against a stale clone
reports stale answers.

## Operations

Pick from the user's phrasing; default to **Check**. **Refresh runs first every
time**, whichever operation follows.

| Operation | Trigger | Effect |
| --- | --- | --- |
| **Refresh** | always, before any of the others | Pull the repo's checked-out branch from its `origin`. |
| **Check** | "check script versions", "am I up to date" | Read-only report. |
| **Sync** | "update/install my scripts", "sync scripts" | Check, then copy repo → `~/bin` for the entries the user confirms. |
| **Bookkeeping** | "regenerate the manifest", "bump <name>" | Rewrite `manifest.json` from the scripts' version headers; bump a script's `# version:` when asked. |

## Paths

- **Repo root** — the folder containing `manifest.json`. Resolve as the
  current working directory or its nearest ancestor holding that file; if none
  is found, ask the user for the path. Never guess another location.
- **Install root** — `$HOME/bin` on Linux/macOS, `$env:USERPROFILE\bin` on
  Windows (override only if the user names another). A script installs as the
  single file `<installRoot>/<name>`, copied from the repo's `<path>` and made
  executable.
- **Kinds.** Every manifest entry carries `"kind": "script"`. There is no
  default and no other kind — an entry with a missing or different `kind` is an
  error, and both scripts refuse the whole manifest rather than guessing.
- `~/bin` is **not owned by the repo**: it holds scripts and binaries from many
  sources. Never enumerate it, never mirror it, and never delete anything in it
  — the only writes are single-file copies of confirmed manifest entries. There
  is no "installed but not in manifest" report for this skill.

## Version headers

A bash script has no frontmatter, so the version lives in a comment:

```bash
#!/usr/bin/env bash
# version: 1.2.0
```

The first line matching `# version: <x.y.z>` (case-insensitive `version`,
whitespace after `#` optional) within the **first 15 lines** of the file is the
script's version. By convention it sits directly under the shebang. Both
comparison scripts and the installed copies are read the same way.

## Manifest format

`manifest.json` at the repo root:

```json
{
  "manifestVersion": 1,
  "updated": "<YYYY-MM-DD>",
  "installRoot": "~/bin",
  "entries": [
    { "name": "<name>", "version": "<x.y.z>", "kind": "script", "path": "<name>" }
  ]
}
```

Rules: `name` must equal the script's filename and `path` is the script's
location relative to the repo root, with forward slashes (usually just the
filename — scripts normally sit at the top level — but a subfolder like
`tools/<name>` is allowed; installation is always flat: `~/bin/<name>`).
Entries are ordered by name. Every managed script appears; a script with no
`# version:` header is an error — add `# version: 1.0.0` under the shebang
rather than omitting the entry.

## Refresh — pull from origin

Always bring the repo up to date with its own remote before comparing anything.
Never skip this because the clone "looks current".

1. **Verify it is a git repo with an origin.** In the resolved repo root:

   ```bash
   git -C "<repo>" remote get-url origin
   ```

   Whatever `origin` points to is the upstream — do not verify it against a
   fixed URL, and never add or rewrite a remote. If the folder is not a git
   repo or has no `origin`, skip the pull, say so, and continue against the
   local files.
2. **Pull, fast-forward only.** Never rebase, merge, stash, reset, or discard
   local work to make the pull succeed:

   ```bash
   git -C "<repo>" fetch origin
   git -C "<repo>" pull --ff-only
   ```

3. **Handle the outcomes:**

   | Outcome | What it means | Do |
   | --- | --- | --- |
   | Already up to date | clone matches upstream | continue silently |
   | Fast-forwarded | new upstream commits pulled in | continue; mention how many commits arrived |
   | `--ff-only` refused | local branch has diverged from upstream, or local commits are unpushed | report the divergence and continue against the local snapshot — the user resolves it, not this skill |
   | Pull blocked by local modifications | uncommitted edits would be overwritten | name the files, continue against the local snapshot, never stash or discard |
   | Fetch failed (offline, auth, host down) | upstream unreachable | report the error verbatim and continue against the local snapshot |

   In every case except a clean pull, **say in the final report that the
   comparison ran against a possibly stale clone**, and why.
4. Note the branch — pull only the checked-out branch. If it is not the repo's
   default branch, say so; versions are tracked on the default branch.

Nothing here touches `~/bin`. Refresh only updates the repo.

## Check

Run Refresh first, then run the bundled script for the current platform. The
comparison scripts live in **this skill's install folder**
(`~/.claude/skills/script-version-check/scripts/`), not in the scripts repo.
The two are ports of each other — same statuses, same sections, same summary
line — so pick by shell, not by preference.

On Windows:

```powershell
& "$env:USERPROFILE\.claude\skills\script-version-check\scripts\Compare-ScriptVersions.ps1" -RepoRoot "<repo>"
```

On Linux/macOS (also works in Git Bash / WSL):

```bash
bash "$HOME/.claude/skills/script-version-check/scripts/compare-script-versions.sh" --repo-root "<repo>"
```

Add `-Json` / `--json` when you need to consume the result programmatically, or
`-InstallRoot <path>` / `--install-root <path>` for a non-default install
location. Both scripts discover the repo root themselves by walking up from the
current directory, so the root flag is optional when already inside the repo.

The bash port needs only `bash`, `awk`, `grep`, and `sed`; it uses `jq` to read
the manifest when it is on `PATH` and falls back to a built-in parser when it
is not.

The script prints one row per manifest entry with `Name`, `Kind` (always
`script`), `Manifest` (version in `manifest.json`), `Repo` (version in
the repo copy's header), `Local` (version in the installed copy's header), and
a status:

| Status | Meaning | Action |
| --- | --- | --- |
| `OK` | local == manifest | none |
| `OUTDATED` | local < manifest | offer to update (Sync) |
| `AHEAD` | local > manifest | local edits never committed back — flag, do not overwrite without asking |
| `MISSING` | nothing at `~/bin/<name>` | offer to install (Sync) |
| `UNVERSIONED` | installed file has no `# version:` header | pre-versioning install; treat as OUTDATED and offer to update |
| `DIFFERENT` | versions not comparable as `Major.Minor.Patch` | report verbatim, do not auto-resolve |

An entry whose `kind` is missing or is not `script` aborts the whole run — fix
the manifest with Bookkeeping, then re-run.

It also prints a **Manifest drift** section when `Manifest` != `Repo` — the
manifest is stale relative to the repo; fix with Bookkeeping before trusting
any status column.

Summarize in prose: how many OK, what is stale, what is missing. Do not restate
the whole table if everything is `OK`.

## Sync

1. Run Check first (which runs Refresh). Refuse to sync while manifest drift
   exists — fix with Bookkeeping, otherwise you would install a version the
   manifest misreports. If Refresh could not reach upstream, say so and get
   confirmation before installing anything: you would be copying a clone of
   unknown freshness into `~/bin`.
2. List exactly what will change (`<name>: 1.0.0 → 1.2.0`, `<name>: install`)
   and get confirmation. `AHEAD` and `DIFFERENT` entries are excluded by default
   — call them out and only include one if the user explicitly says so, since
   overwriting discards local edits that were never committed to the repo.
3. For each confirmed entry, copy the single file and keep it executable —
   never touch any other file in `~/bin`:

   On Windows:

   ```powershell
   New-Item -ItemType Directory -Force "<installRoot>" | Out-Null
   Copy-Item "<repo>\<path>" "<installRoot>\<name>" -Force
   ```

   On Linux/macOS:

   ```bash
   mkdir -p "<installRoot>"
   install -m 0755 "<repo>/<path>" "<installRoot>/<name>"
   ```

4. Re-run Check and report the resulting status. If `~/bin` is not on the
   user's `PATH`, mention it — installed scripts will not resolve otherwise.

Only copy repo → `~/bin`. Never copy `~/bin` → repo; edits belong in the repo,
made as ordinary file edits and committed.

## Bookkeeping — manifest and versions

Run Refresh first here too — regenerating the manifest from a stale clone
reintroduces versions upstream has already moved past.

**Regenerate the manifest.** Walk the repo root (top level and any subfolders
the existing manifest's `path` values point into) for files whose first line is
a bash shebang (`#!/usr/bin/env bash`, `#!/bin/bash`, or `#!/bin/sh`), read
each script's `# version:` header, and rewrite `manifest.json` in the
format above. Non-script files (configs, docs, licenses, template folders) are
never manifest entries. A script with no header is an error — add
`# version: 1.0.0` directly under the shebang rather than omitting the entry.
Ask before adding a previously unmanaged script the user has not mentioned.

**Bump a version.** After a script's content changes:

- **patch** — wording, typos, comment or output changes that do not change
  behavior.
- **minor** — new capability, new option, or new supported input, backward
  compatible.
- **major** — changed arguments, flags, output format, or side effects;
  anything that invalidates how a caller invokes it.

Edit the `# version:` header in the script, then update the same entry in
`manifest.json`. The two must always agree — that is what Check calls
drift.

## Reporting

Lead with the verdict (`all 28 entries up to date`, or `3 outdated, 1
missing`). Show the table only when something needs attention. Never modify a
script's content as a side effect of a version check.

Report the Refresh result in one line before the verdict, but only when it was
not a clean no-op: `pulled 4 commits from origin`, `origin unreachable —
compared against the local clone from <date>`, `local branch has diverged from
origin/master`. A clone that was already up to date needs no mention.

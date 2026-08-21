---
name: new-julia-project
version: 1.0.0
description: Scaffold a new Julia package using PkgTemplates — generates the package directory with Project.toml, git repo, a .gitignore tuned for Julia, MIT license, README, and a GitHub Actions CI workflow that builds, tests, lints, and checks formatting. Also finishes a partially set-up Julia package, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new Julia project or package, or to complete/fill in the setup of an existing one.
---

# New Julia package

Create a fresh Julia package via `PkgTemplates`: `Project.toml` (version 0.1.0),
a git repo with Julia-aware ignore rules, default `src/` + `test/`, MIT license,
README, and a custom GitHub Actions CI workflow.

## Inputs

- **project name** (required) — the package name.

## Tool preference

Prefer language-native tooling (`PkgTemplates` — it generates the package,
git repo, `.gitignore`, and MIT license itself, with author and year from git
config); use npx generators (`npx license`) only on the partially-set-up path
where PkgTemplates cannot run; fall back to the bundled
`reference/mit-license.txt` only when neither is available.

## Partially set-up projects

PkgTemplates refuses to generate into an existing non-empty path, so a
partially set-up package skips generation instead:

- If the folder exists and contains a `Project.toml`, skip steps 1–3 (just
  `cd` into the folder) and apply the remaining steps, adding only what's
  missing: ensure the git
  repo exists (`git init` if not), ensure `.gitignore` covers the Julia rules
  from step 2's `ignore` list plus `.vscode/` (append missing entries, never
  replace the file), and if `LICENSE` is missing generate it with
  `npx license MIT` (year and author from git config; fall back to
  `reference/mit-license.txt` with `<YEAR>` → current year followed by
  `git config user.name`), committing it as "Added MIT License".
- An artifact that already exists (LICENSE, README, workflow) is kept as-is,
  not overwritten; skip that step and its commit.
- Only commit a step that actually changed something, keeping the same commit
  messages.
- If the folder is non-empty but has no `Project.toml`, stop and ask the user
  how to proceed.

## Steps

Run from the directory where the package should be created. Requires `git` on
PATH and `julia` with the `PkgTemplates` package installed.

1. PkgTemplates refuses to generate into an existing path. If `<project name>`
   already exists as an **empty** folder, remove it first so PkgTemplates can
   recreate it — `rmdir <project name>` (fails on a non-empty folder, which is
   the point). If the folder exists and is non-empty, see "Partially set-up
   projects" above.

2. Generate the package. Substitute `<project name>` in both places:

   ```bash
   julia --project="<project name>" -e 'using PkgTemplates; PkgTemplates.Template(; interactive=false, dir=".", plugins=[ProjectFile(; version=v"0.1.0"), !Readme, License(; name="MIT"), Git(; ignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem", "docs/build/", "docs/site/", ".vscode/"]), !CompatHelper, !TagBot, !GitHubActions, !Dependabot])("<project name>")'
   ```

   The `!Plugin` entries disable the named default plugins (the stock `Readme`
   and `GitHubActions` output — this skill supplies its own). The `License`
   plugin generates the MIT `LICENSE` with author and year from git config, and
   the `Git` plugin's `ignore` list (including `.vscode/`) becomes the
   `.gitignore`. PkgTemplates already inits the git repo and makes the first
   commit, which includes the license.

3. `cd <project name>`. Spot-check `LICENSE` — the copyright line should read
   `Copyright (c) <current year> <git config user.name>`.

4. README: `echo "# <project name>" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`.

5. CI workflow — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml`.

   The template `uses:` pins (`@v4`, `@v2`, `@v1`) are a baseline and may be
   stale. Before committing, resolve the **latest stable major version** of each
   action and update its `uses:`:

   - `actions/checkout`
   - `julia-actions/setup-julia`
   - `julia-actions/cache`
   - `julia-actions/julia-buildpkg`
   - `julia-actions/julia-runtest`

   Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/julia-actions/setup-julia 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its major
   — `v2.6.0` → `julia-actions/setup-julia@v2`. If `git ls-remote` is
   unavailable, read the resolved tag from
   `https://github.com/<owner>/<repo>/releases/latest`. Leave the Julia
   `version: '1'` input as-is (it tracks the latest stable Julia 1.x).

   Commit: `git add --all && git commit -m "Added GitHub Actions CI workflow"`.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **`build-and-test`** job: every trigger — `julia-buildpkg` (compile/build) +
  `julia-runtest` (`Pkg.test`).
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so the JuliaFormatter format check and the JET static lint run **only on pull
  requests**.

## Verify the workflow with act

Run the CI workflow locally in Docker with [act](https://github.com/nektos/act)
before pushing — when the tooling is present. First check for it:

```bash
command -v act && docker info >/dev/null 2>&1
```

If `act` is not on PATH or Docker is not running, **skip this whole section** —
it is optional validation, not a failure; state in the final report that act
verification was skipped and why. Otherwise, from the package root:

1. `act -l` — list the jobs act resolves.
2. `act push` — only `build-and-test` runs; `lint-and-format` is skipped by the
   PR gate.
3. `act pull_request` — both jobs run.

The medium image (`catthehacker/ubuntu:act-latest`) is sufficient; pin it
non-interactively with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
Confirm step 2 skips lint/format and step 3 includes them.

Report the created package path, any steps skipped because the package was
already partially set up, and the act results (or that act verification was
skipped and why).

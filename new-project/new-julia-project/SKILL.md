---
name: new-julia-project
description: Scaffold a new Julia package using PkgTemplates — generates the package directory with Project.toml, git repo, a .gitignore tuned for Julia, and a GitHub Actions CI workflow that builds, tests, lints, and checks formatting. Use when the user asks to start/create/initialize/bootstrap a new Julia project or package.
---

# New Julia package

Create a fresh Julia package via `PkgTemplates`: `Project.toml` (version 0.1.0),
a git repo with Julia-aware ignore rules, default `src/` + `test/`, and a custom
GitHub Actions CI workflow.

## Inputs

- **project name** (required) — the package name.

## Steps

Run from the directory where the package should be created. Requires `julia`
with the `PkgTemplates` package installed.

1. Generate the package. Substitute `<project name>` in both places:

   ```bash
   julia --project="<project name>" -e 'using PkgTemplates; PkgTemplates.Template(; interactive=false, dir=".", plugins=[ProjectFile(; version=v"0.1.0"), !Readme, Git(; ignore=["*.jl.cov", "*.jl.*.cov", "*.jl.mem", "docs/build/", "docs/site/"]), !CompatHelper, !TagBot, !GitHubActions, !Dependabot])("<project name>")'
   ```

   The `!Plugin` entries disable the named default plugins (including the stock
   `GitHubActions` workflow — this skill supplies its own). PkgTemplates already
   inits the git repo and makes the first commit.

2. `cd <project name>`.

3. CI workflow — copy `templates/ci.yml` (this skill dir) to
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
before pushing. Requires `act` on PATH and Docker Desktop running (`docker info`
must succeed). From the package root:

1. `act -l` — list the jobs act resolves.
2. `act push` — only `build-and-test` runs; `lint-and-format` is skipped by the
   PR gate.
3. `act pull_request` — both jobs run.

The medium image (`catthehacker/ubuntu:act-latest`) is sufficient; pin it
non-interactively with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
Confirm step 2 skips lint/format and step 3 includes them.

Report the created package path and the act results.

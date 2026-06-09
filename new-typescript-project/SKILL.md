---
name: new-typescript-project
description: Scaffold a new TypeScript project with npm or pnpm (per the user's choice) — git repo with seeded commits, MIT license, .gitignore, README, strict tsconfig, ESLint, Prettier, Vitest, and a GitHub Actions CI workflow that compiles, tests, lints, and checks formatting. Use when the user asks to start/create/initialize/bootstrap a new TypeScript or TS project, optionally specifying npm or pnpm.
---

# New TypeScript project (npm or pnpm)

Bootstrap a strict TypeScript project in the **current directory** with ESLint,
Prettier, Vitest, and a GitHub Actions CI pipeline. Each setup step is its own
commit, matching the other `new-*-project` skills.

## Inputs

- **package manager** — `npm` or `pnpm`. Ask if the user did not say. This
  selects every install command and the CI workflow template.

## Before starting

Operates in the current working directory. `cd` into the intended (already
created) project folder first and confirm it is correct.

## Package-manager command map

| Action          | npm                                  | pnpm                                  |
| --------------- | ------------------------------------ | ------------------------------------- |
| init manifest   | `npm init -y`                        | `pnpm init`                           |
| add dev deps    | `npm install -D <pkgs>`              | `pnpm add -D <pkgs>`                   |
| CI template     | `templates/ci-npm.yml`               | `templates/ci-pnpm.yml`               |

## Steps

1. Init repo + empty commit:

   ```bash
   git init
   git commit --allow-empty -m "New repo"
   ```

2. `.gitignore` (then `git add --all && git commit -m "Added node.js default .gitignore"`):

   ```bash
   npx gitignore node
   ```

   Append a line for the TypeScript build output: `dist/`.

3. MIT license: write `LICENSE` from `reference/mit-license.txt` with `<YEAR>` →
   current year. `git add LICENSE && git commit -m "Added MIT License"`.

4. README: `echo "# $(basename "$PWD")" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`.

5. Init the manifest (see command map). Then set `"type": "module"` in
   `package.json` and add these scripts:

   ```json
   "scripts": {
     "build": "tsc",
     "lint": "eslint .",
     "format": "prettier --write .",
     "format:check": "prettier --check .",
     "test": "vitest run"
   }
   ```

   Commit: `git add --all && git commit -m "Added default package manifest"`.

6. Install dev dependencies (see command map for the install verb):

   ```text
   typescript @types/node eslint @eslint/js typescript-eslint prettier vitest
   ```

   Commit the lockfile + manifest:
   `git add --all && git commit -m "Added TypeScript toolchain"`.

7. Copy config + source files from this skill, then
   `git add --all && git commit -m "Added tsconfig, lint/format config, and sample source"`:

   - `templates/tsconfig.json` → `tsconfig.json`
   - `templates/eslint.config.mjs` → `eslint.config.mjs`
   - `templates/prettierrc.json` → `.prettierrc.json`
   - `templates/index.ts` → `src/index.ts`
   - `templates/index.test.ts` → `src/index.test.ts`

8. CI workflow — copy the package-manager-specific template to
   `.github/workflows/ci.yml`:

   - npm → `templates/ci-npm.yml`
   - pnpm → `templates/ci-pnpm.yml`

   The template `uses:` pins (`@v4`, …) are a baseline and may be stale. Before
   committing, resolve the **latest stable major version** of every action in
   the copied file and update each `uses:` to match. Actions to check:

   - `actions/checkout`
   - `actions/setup-node`
   - `pnpm/action-setup` (pnpm template only)

   Resolve the latest stable tag for each with `git ls-remote` (no `gh`, no auth
   required), e.g.:

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver from the output (ignore tags containing `-`,
   e.g. `-beta`/`-rc`). Pin to the latest **major** tag — if the highest is
   `v4.2.2`, write `actions/checkout@v4`. Apply the same to `actions/setup-node`
   and `pnpm/action-setup`, and bump the `version:` input of `pnpm/action-setup`
   to the latest stable pnpm major if it has moved past `9`.

   If `git ls-remote` is unavailable, fetch the releases page
   `https://github.com/<owner>/<repo>/releases/latest` and read the resolved tag.

   Commit: `git add --all && git commit -m "Added GitHub Actions CI workflow"`.

## CI behavior (already encoded in the templates)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **`build-and-test`** job: runs on every trigger — compiles (`build`) and runs
  tests (`test`).
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so linting and format checking run **only on pull requests**.

## Verify the workflow with act

Run the CI workflow locally in Docker with [act](https://github.com/nektos/act)
to confirm it is green before pushing. Requires `act` on PATH and Docker Desktop
running (`docker info` must succeed).

Run from the project root:

1. List the jobs act resolves per event (sanity check):

   ```bash
   act -l
   ```

2. Simulate a **push** — only `build-and-test` should run; `lint-and-format` is
   skipped by the PR gate:

   ```bash
   act push
   ```

3. Simulate a **pull request** — both `build-and-test` and `lint-and-format`
   should run:

   ```bash
   act pull_request
   ```

Notes:

- First run prompts for an image size; the medium image
  (`catthehacker/ubuntu:act-latest`) is sufficient. Pin it non-interactively
  with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
- act reads `.github/workflows/ci.yml` directly — no extra config needed.
- Confirm step 2 skips lint/format and step 3 includes them; that proves the
  pull-request gating works.

After both act runs pass, report the package manager used, the created files,
and the act results.

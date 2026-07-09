---
name: new-typescript-project
description: Scaffold a new TypeScript project with pnpm — creates the directory, then adds a strict tsconfig, ESLint, Prettier, Vitest, TypeDoc, MIT license, .gitignore, README, CI/CD GitHub Actions workflows, and seeded git commits. Also finishes a partially set-up TypeScript project, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new TypeScript, TS, or pnpm project, or to complete/fill in the setup of an existing one.
---

# New TypeScript project (pnpm)

Create a fresh strict-mode TypeScript project managed by pnpm, then layer on
ESLint, Prettier, Vitest, TypeDoc, MIT license, README, CI/CD workflows, and
per-step git commits. Also finishes a partially set-up project, adding only
what's missing (see "Partially set-up projects").

## Inputs

- **project name** (required) — directory + package name.

## Tool preference

Prefer language-native tooling (`pnpm`, `tsc --init`) for anything it can
generate; use generators (`pnpm dlx gitignore`, `pnpm dlx license`) where there
is no native equivalent; fall back to the bundled templates where no generator
exists (ESLint/Prettier config, sample sources, workflows) or when generation
fails.

## Partially set-up projects

This skill also finishes a project that is already partially set up. Every step
is idempotent — before running a step, check whether its output already exists:

- If the repo already has commits, skip the "New repo" empty commit.
- `.gitignore` is merged, not replaced: append only the missing entries
  (including `dist/`, `docs/`, `.claude/`, and `.vscode/`).
- An artifact that already exists (LICENSE, README, tsconfig, lint/format
  config, sources, workflows) is kept as-is, not overwritten; skip that step
  and its commit. Note `tsc --init` errors if `tsconfig.json` exists — keep the
  existing file.
- If `package.json` already exists, keep it; just ensure `"type": "module"`,
  `"main"`, `"types"`, and the scripts below are present, and install only the
  missing dev dependencies.
- Only commit a step that actually changed something, keeping the same commit
  messages.

## Steps

Run these from the directory where the new project folder should live. Requires
`pnpm`, `node`, and `git` on PATH.

1. Create and enter the project (`mkdir -p` so an already-created folder is
   used as-is), init the repo, seed an empty commit:

   ```bash
   mkdir -p <project name>
   cd <project name>
   git init
   git commit --allow-empty -m "New repo"
   ```

2. `.gitignore` — generate the Node baseline, then append local additions:

   ```bash
   pnpm dlx gitignore node
   ```

   Append:

   ```text
   # TypeScript build output
   dist/

   # TypeDoc output
   docs/

   # Claude AI
   .claude/

   # VS Code
   .vscode/
   ```

   Then: `git add .gitignore && git commit -m "Added .gitignore"`

3. MIT license — generates `LICENSE` with the current year and the author from
   npm config:

   ```bash
   pnpm dlx license MIT
   ```

   Verify the copyright line reads `Copyright (c) <current year> <git config
   user.name>` and fix it up if not. If generation is unavailable, fall back to
   `reference/mit-license.txt` with `<YEAR>` → current year followed by the
   author from `git config user.name`.

   Then: `git add LICENSE && git commit -m "Added MIT License"`

4. README: `echo "# <project name>" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`

5. Manifest: `pnpm init`, then edit `package.json` — set `"name"` to the
   project name, set `"type": "module"`, replace `"main": "index.js"` with
   `"main": "dist/index.js"`, add `"types": "dist/index.d.ts"`, and add these
   scripts:

   ```json
   "scripts": {
     "build": "tsc",
     "test": "vitest run",
     "coverage": "vitest run --coverage --coverage.reporter=lcov",
     "lint": "eslint .",
     "format": "prettier --write .",
     "format:check": "prettier --check .",
     "docs": "typedoc src/index.ts"
   }
   ```

   Commit: `git add package.json && git commit -m "Added default package manifest"`

6. Install dev dependencies:

   ```bash
   pnpm add -D typescript @types/node eslint @eslint/js typescript-eslint prettier vitest @vitest/coverage-v8 typedoc
   ```

   Commit the manifest + lockfile:
   `git add --all && git commit -m "Added TypeScript toolchain"`

7. Generate `tsconfig.json` with `tsc --init`, then patch it:

   ```bash
   pnpm exec tsc --init \
       --outDir dist \
       --rootDir src \
       --noUnusedLocals \
       --noUnusedParameters
   ```

   `tsc --init` layers these flags over the current TypeScript version's
   recommended defaults (strict, declaration, nodenext modules, …), so the
   result tracks upstream best practice rather than a frozen snapshot. The
   flags are only the settings that diverge from those defaults. Three things
   it gets wrong for this scaffold must be patched afterward —
   `include`/`exclude` have no CLI flags, and its `types: []` blocks the
   installed `@types/node` (first `node:` import or `process` reference fails
   with TS2591):

   ```bash
   node - << 'EOF'
   const ts = require('typescript');
   const fs = require('fs');
   const config = ts.readConfigFile('tsconfig.json', ts.sys.readFile).config;
   config.compilerOptions.types = ['node'];
   config.include = ['src'];
   config.exclude = ['**/*.test.ts'];
   fs.writeFileSync('tsconfig.json', JSON.stringify(config, null, 2) + '\n');
   EOF
   ```

   (`ts.readConfigFile`, not `JSON.parse` — the generated file may contain
   comments. The `exclude` keeps test files out of `dist/`; without it Vitest
   runs each test twice, once from `src/` and once compiled.)

   Then copy the remaining config + source files from this skill:

   - `templates/eslint.config.mjs` → `eslint.config.mjs`
   - `templates/prettierrc.json` → `.prettierrc.json`
   - `templates/prettierignore` → `.prettierignore`
   - `templates/index.ts` → `src/index.ts`
   - `templates/index.test.ts` → `src/index.test.ts`

   Then run `pnpm format` once to normalize anything earlier shell steps wrote
   (line endings, BOM), verify the toolchain end-to-end —

   ```bash
   pnpm build && pnpm test && pnpm lint && pnpm format:check
   ```

   — and commit:
   `git add --all && git commit -m "Added tsconfig, lint/format config, and sample source"`

8. CI workflow — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml`. No placeholder to replace (TypeDoc emits its own
   `index.html`, so the docs job needs no redirect).

   The template `uses:` pins are a current-as-of-authoring baseline and may have
   gone stale. Before committing, resolve the **latest stable major version** of
   each versioned action and update its `uses:`:

   - `actions/checkout`
   - `pnpm/action-setup`
   - `actions/setup-node`
   - `actions/configure-pages`
   - `actions/upload-pages-artifact`
   - `actions/deploy-pages`
   - `codecov/codecov-action`

   Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its major
   — `v6.0.3` → `actions/checkout@v6`. If `git ls-remote` is unavailable, read
   the resolved tag from `https://github.com/<owner>/<repo>/releases/latest`.

   One more baseline to refresh in the same pass: `node-version:` — bump to
   the current active LTS major if it has moved past `24` (check
   https://endoflife.date/nodejs or
   https://nodejs.org/en/about/previous-releases).

   Note: `pnpm/action-setup` deliberately has **no `version:` input** — it
   reads the pnpm version from the `packageManager` field that `pnpm init`
   wrote into `package.json`. Don't add one; if both are present and disagree,
   the action fails with "Multiple versions of pnpm specified".

   Don't commit yet — the CD workflow (step 9) is committed together with it.

9. CD workflow (release automation) — copy `templates/cd.yml` (this skill dir)
   to `.github/workflows/cd.yml`. No placeholder to replace. Its versioned
   actions (`actions/checkout`, `pnpm/action-setup`, `actions/setup-node`) and
   the pnpm/node baselines are the same ones resolved in step 8 — reuse those
   pins. Commit both workflows together:
   `git add --all && git commit -m "Added GitHub Actions CI/CD workflows"`.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **Concurrency**: in-progress runs for the same ref are cancelled on new pushes
  to a pull request (`cancel-in-progress` only for PR events).
- **`build-and-test`** job: every trigger — `pnpm build` (tsc) + `pnpm test`
  (Vitest), across an **OS matrix** (`ubuntu-latest`, `windows-latest`,
  `fail-fast: false`).
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so `eslint .` and `prettier --check .` run **only on pull requests**.
- **`docs`** job: gated by `if: github.ref == 'refs/heads/master'` and
  `needs: build-and-test`, so it runs **only on master after build/test pass**.
  Builds TypeDoc HTML (`pnpm docs` → `docs/`) and deploys it to GitHub Pages.
  Requires Pages enabled for the repo (Settings → Pages → Source: GitHub
  Actions).
- **`coverage`** job: gated by `if: github.ref == 'refs/heads/develop'` and
  `needs: build-and-test`, so it runs **only on develop**. Generates lcov via
  `vitest run --coverage` (`@vitest/coverage-v8`) and uploads
  `coverage/lcov.info` to Codecov. Requires a `CODECOV_TOKEN` repo secret
  (Settings → Secrets and variables → Actions).

## CD behavior (encoded in the template)

`cd.yml` is the release-automation workflow. Triggers on push to `master` that
touches `package.json`.

- **`build`** job: `pnpm build` + `pnpm test` gate — never tag a broken master.
- **`release`** job (`needs: build`, `permissions: contents: write`): reads the
  version from `package.json` via
  `node -p "require('./package.json').version"`, and **if that tag doesn't
  already exist**, creates + pushes `v<version>`, then merges `master` into
  `develop` (`--no-ff`). Idempotent — re-running on an unchanged version is a
  no-op.

## Adjust per project

The templates are a strict baseline; toggle these per project:

- **`docs` job** (`ci.yml`) — on by default: builds TypeDoc and deploys to
  GitHub Pages on `master`. Remove the entire `docs` job for an
  application-only repo or any repo with no Pages setup. Requires Pages enabled
  (Settings → Pages → Source: GitHub Actions); without it the job fails. If the
  public API grows beyond `src/index.ts`, update the `docs` script's entry
  points to match.
- **submodules** — off by default. If the repo has a `.gitmodules`, add
  `with: submodules: true` under each `actions/checkout` step that needs the
  submodule contents (at minimum `build-and-test` in `ci.yml`). Use `recursive`
  for nested submodules. Private submodules also need a PAT in `token:` — the
  default `GITHUB_TOKEN` cannot clone other private repos.

## Verify the workflow with act

Run the CI workflow locally in Docker with [act](https://github.com/nektos/act)
before pushing — when the tooling is present. First check for it:

```bash
command -v act && docker info >/dev/null 2>&1
```

If `act` is not on PATH or Docker is not running, **skip this whole section** —
it is optional validation, not a failure; state in the final report that act
verification was skipped and why. Otherwise, from the project root:

1. `act -l` — list the jobs act resolves.
2. `act push` — only `build-and-test` runs; `lint-and-format` is skipped by the
   PR gate.
3. `act pull_request` — both jobs run.

The medium image (`catthehacker/ubuntu:act-latest`) is sufficient; pin it
non-interactively with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
Confirm step 2 skips lint/format and step 3 includes them. Caveats: act runs
Linux containers, so the `windows-latest` matrix leg can't execute (expect only
the `ubuntu-latest` leg); the `docs` job (real GitHub Pages) and `coverage` job
(Codecov, develop-only) can't run under act. Scope act to the runnable jobs with
`act push -j build-and-test` and `act pull_request -j lint-and-format`.

Report the created project path, any steps skipped because the project was
already partially set up, and the act results (or that act verification was
skipped and why).

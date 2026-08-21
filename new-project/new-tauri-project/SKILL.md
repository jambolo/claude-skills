---
name: new-tauri-project
version: 1.0.0
description: Scaffold a new Tauri desktop application — a cargo workspace with a UI-agnostic Rust compute-core crate (src-core) and a thin Tauri shell crate (src-tauri), plus a TypeScript + Vite + Vitest frontend (src) managed by pnpm, with ESLint, Prettier, MIT license, .gitignore, README, CI/CD GitHub Actions workflows, and seeded git commits. Also finishes a partially set-up Tauri project, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new Tauri app, desktop app, or Rust + TypeScript GUI project, or to complete/fill in the setup of an existing one. For a pure Rust project (no UI) use new-rust-project; for a pure TypeScript/Node project use new-typescript-project.
---

# New Tauri project (Rust core + TypeScript frontend)

Create a fresh Tauri desktop application: a cargo workspace holding a
UI-agnostic Rust compute core (`src-core`) and a thin Tauri shell
(`src-tauri`), a strict-mode TypeScript frontend (`src`) built with Vite and
tested with Vitest, ESLint, Prettier, MIT license, README, CI/CD workflows,
and per-step git commits. Also finishes a partially set-up project, adding
only what's missing (see "Partially set-up projects").

## Architecture the skeleton encodes

Three strictly separated layers — the sample "greet" flow wires one example
through all of them so a new project can grow by imitation:

- **`src-core/`** (`<name>-core` crate) — all application logic and its
  tests. No Tauri dependency; tests run headless.
- **`src-tauri/`** (`<name>` crate) — thin shell: owns the window, exposes
  core functions as Tauri commands, defines the JSON protocol (serde structs,
  camelCase). Heavy work belongs on a worker thread
  (`tauri::async_runtime::spawn_blocking`), not the UI thread.
- **`src/`** (frontend) — `api.ts` is the **only** module that imports
  `@tauri-apps/api`; it mirrors the protocol types. `main.ts` is DOM glue.
  Tests mock the IPC boundary (`@tauri-apps/api/mocks`) or the `api` module.

## Inputs

- **project name** (required) — directory name, package name, and shell crate
  name; kebab-case.
- **bundle identifier** (optional) — reverse-DNS id for `tauri.conf.json`;
  defaults to `com.example.<project name with hyphens removed>`.

## Template tokens

Replace these in every copied template that contains them:

| Token | Value |
| --- | --- |
| `@PROJECT_NAME@` | project name as given (kebab-case) |
| `@PROJECT_SNAKE@` | project name with `-` → `_` (Rust identifier) |
| `@PROJECT_IDENT@` | project name with `-` removed (bundle identifier) |

## Tool preference

Prefer language-native tooling (`pnpm`, `cargo`, `pnpm tauri icon`) for
anything it can generate; use generators (`pnpm dlx gitignore`,
`pnpm dlx license`) where there is no native equivalent; fall back to the
bundled templates where no generator exists or when generation fails. Two
deliberate deviations from the sibling skills:

- `tsconfig.json` comes from the bundled template, not `tsc --init`: a Vite
  app needs `moduleResolution: bundler` and `noEmit` (Vite does the
  bundling), which is a different shape from the Node-library defaults
  `tsc --init` produces.
- The Rust `.gitignore` entries are appended by hand, not via
  `pnpm dlx gitignore rust`: that generator ignores `Cargo.lock`, which is
  wrong for an application (the lockfile must be committed).

## Partially set-up projects

This skill also finishes a project that is already partially set up. Every
step is idempotent — before running a step, check whether its output already
exists:

- If the repo already has commits, skip the "New repo" empty commit.
- `.gitignore` is merged, not replaced: append only the missing entries
  (including `/target`, `/src-tauri/gen/`, `dist/`, `.claude/`, and
  `.vscode/`).
- An artifact that already exists (LICENSE, README, tsconfig, lint/format
  config, sources, crates, icons, workflows) is kept as-is, not overwritten;
  skip that step and its commit.
- If `package.json` already exists, keep it; just ensure `"private": true`,
  `"type": "module"`, and the scripts below are present, and install only the
  missing dependencies.
- If a workspace `Cargo.toml` already exists, keep it; just ensure
  `src-core` and `src-tauri` are listed in `members`. If a crate directory
  already exists, leave its contents alone.
- If `src-tauri/icons/` already has icons, skip icon generation.
- Only commit a step that actually changed something, keeping the same commit
  messages.

## Steps

Run these from the directory where the new project folder should live.
Requires `pnpm`, `node`, `cargo`, and `git` on PATH. On Windows the Rust
build also needs the MSVC toolchain; on Linux it needs Tauri's system
libraries (webkit2gtk et al.) — if the first `cargo build` fails with missing
system dependencies, report the [Tauri prerequisites](https://tauri.app/start/prerequisites/)
rather than debugging further.

1. Create and enter the project (`mkdir -p` so an already-created folder is
   used as-is), init the repo, seed an empty commit:

   ```bash
   mkdir -p <project name>
   cd <project name>
   git init
   git commit --allow-empty -m "New repo"
   ```

2. `.gitignore` — generate the Node baseline, then append the Rust, Tauri,
   and local additions:

   ```bash
   pnpm dlx gitignore node
   ```

   Append:

   ```text
   # Rust build output
   /target

   # rustfmt backup files
   **/*.rs.bk

   # MSVC debug info
   *.pdb

   # Tauri generated schemas
   /src-tauri/gen/

   # Vite build output
   dist/

   # Claude AI
   .claude/

   # VS Code
   .vscode/
   ```

   Do **not** ignore `Cargo.lock` or `pnpm-lock.yaml` — this is an
   application, so both lockfiles are committed.

   Then: `git add .gitignore && git commit -m "Added .gitignore"`

3. MIT license — generates `LICENSE` with the current year and the author
   from npm config:

   ```bash
   pnpm dlx license MIT
   ```

   Verify the copyright line reads `Copyright (c) <current year> <git config
   user.name>` and fix it up if not. If generation is unavailable, fall back
   to `reference/mit-license.txt` with `<YEAR>` → current year followed by
   the author from `git config user.name`.

   Then: `git add LICENSE && git commit -m "Added MIT License"`

4. README: `echo "# <project name>" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`

5. Manifest: `pnpm init`, then edit `package.json` — set `"name"` to the
   project name, add `"private": true` (an app is never published), set
   `"type": "module"`, remove `"main"`, and add these scripts plus the pnpm
   build-script approval for esbuild:

   ```json
   "scripts": {
     "dev": "vite",
     "build": "tsc --noEmit && vite build",
     "preview": "vite preview",
     "tauri": "tauri",
     "test": "vitest run",
     "coverage": "vitest run --coverage --coverage.reporter=lcov",
     "typecheck": "tsc --noEmit",
     "lint": "eslint .",
     "format": "prettier --write .",
     "format:check": "prettier --check ."
   },
   "pnpm": {
     "onlyBuiltDependencies": ["esbuild"]
   }
   ```

   Commit: `git add package.json && git commit -m "Added default package manifest"`

6. Install dependencies:

   ```bash
   pnpm add @tauri-apps/api
   pnpm add -D @tauri-apps/cli typescript vite vitest jsdom @vitest/coverage-v8 eslint @eslint/js typescript-eslint prettier
   ```

   Commit the manifest + lockfile:
   `git add --all && git commit -m "Added TypeScript and Tauri toolchain"`

7. Frontend config + sources — copy from this skill's `templates/`:

   - `templates/tsconfig.json` → `tsconfig.json`
   - `templates/vite.config.ts` → `vite.config.ts`
   - `templates/index.html` → `index.html` (replace `@PROJECT_NAME@`)
   - `templates/eslint.config.mjs` → `eslint.config.mjs`
   - `templates/prettierrc.json` → `.prettierrc.json`
   - `templates/prettierignore` → `.prettierignore`
   - `templates/src/` → `src/` (api.ts, main.ts, styles.css, api.test.ts,
     main.test.ts)

   Then run `pnpm format` once to normalize anything earlier shell steps
   wrote (line endings, BOM), verify the frontend end-to-end —

   ```bash
   pnpm build && pnpm test && pnpm lint && pnpm format:check
   ```

   If `pnpm lint` fails with `typescript-eslint does not support TS <x>` —
   typescript-eslint lags new TypeScript majors — reinstall the newest
   TypeScript release typescript-eslint does support, taken from its own
   declared peer range (never hardcode a version):

   ```bash
   pnpm add -D "typescript@$(node -p "require('typescript-eslint/package.json').peerDependencies.typescript")"
   ```

   Rerun the verification and note the deviation in the report.

   — and commit:
   `git add --all && git commit -m "Added tsconfig, lint/format config, and sample frontend"`

8. Rust workspace — copy from this skill's `templates/`, replacing tokens:

   - `templates/Cargo.toml` → `Cargo.toml` (workspace root; no tokens)
   - `templates/src-core/` → `src-core/` (`@PROJECT_NAME@` in Cargo.toml)
   - `templates/src-tauri/` → `src-tauri/` (`@PROJECT_NAME@` in Cargo.toml
     and tauri.conf.json, `@PROJECT_IDENT@` in tauri.conf.json,
     `@PROJECT_SNAKE@` in src/main.rs)
   - `templates/app-icon.png` → `app-icon.png` (icon source, kept in the
     repo so icons can be regenerated), then generate the icon set:

     ```bash
     pnpm tauri icon app-icon.png
     ```

     This writes `src-tauri/icons/` (the .ico/.icns/.png set referenced by
     `tauri.conf.json`). The Windows build embeds `icons/icon.ico` via
     `tauri-build`, so icons must exist before the first `cargo build`.

   The Rust dependency requirements in the copied `src-tauri/Cargo.toml` are
   a current-as-of-authoring baseline. Refresh them to the latest stable
   releases with cargo itself, keeping the path dependency on the core crate
   as-is:

   ```bash
   cd src-tauri
   cargo add tauri serde_json
   cargo add serde --features derive
   cargo add --build tauri-build
   cd ..
   ```

   If this bumps tauri to a new major, also update the `$schema` URL in
   `tauri.conf.json` (`https://schema.tauri.app/config/<major>`) and expect
   template drift — fix what the compiler reports.

   Run `pnpm format` again (the copied JSON configs are new), then verify the
   Rust side — the frontend must already be built (step 7), because
   `tauri::generate_context!` embeds `dist/` at compile time:

   ```bash
   cargo build --workspace --all-targets && cargo test --workspace
   ```

   The first build compiles the whole Tauri dependency tree and can take
   several minutes. Commit everything, including `Cargo.lock`:
   `git add --all && git commit -m "Added Rust workspace: compute core and Tauri shell"`

9. CI workflow — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml`. No placeholder to replace.

   The template `uses:` pins are a current-as-of-authoring baseline and may
   have gone stale. Before committing, resolve the **latest stable major
   version** of each versioned action and update its `uses:`:

   - `actions/checkout`
   - `pnpm/action-setup`
   - `actions/setup-node`
   - `Swatinem/rust-cache`
   - `codecov/codecov-action`

   Leave `dtolnay/rust-toolchain@stable` and
   `taiki-e/install-action@cargo-llvm-cov` as-is — they are pinned to a
   channel / tool name, not a version tag.

   Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its
   major — `v6.0.3` → `actions/checkout@v6`. If `git ls-remote` is
   unavailable, read the resolved tag from
   `https://github.com/<owner>/<repo>/releases/latest`.

   `node-version: lts/*` needs no refresh — setup-node resolves the current
   Node LTS at run time.

   Note: `pnpm/action-setup` deliberately has **no `version:` input** — it
   reads the pnpm version from the `packageManager` field that `pnpm init`
   wrote into `package.json`. Don't add one; if both are present and
   disagree, the action fails with "Multiple versions of pnpm specified".

   Don't commit yet — the CD workflow (step 10) is committed together with
   it.

10. CD workflow (release automation) — copy `templates/cd.yml` (this skill
    dir) to `.github/workflows/cd.yml`. No placeholder to replace. Its
    versioned actions and the pnpm/node baselines are the same ones resolved
    in step 9 — reuse those pins. Commit both workflows together:
    `git add --all && git commit -m "Added GitHub Actions CI/CD workflows"`.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull
  requests.
- **Concurrency**: in-progress runs for the same ref are cancelled on new
  pushes to a pull request (`cancel-in-progress` only for PR events).
- **`build-and-test`** job: every trigger — `pnpm build` + `pnpm test`, then
  `cargo build --workspace --all-targets` + `cargo test --workspace`, across
  an **OS matrix** (`ubuntu-latest`, `windows-latest`, `macos-latest`,
  `fail-fast: false`, per-OS cache key) — one leg per platform the app ships
  on, since Tauri does not cross-compile. The frontend builds **before** the
  Rust side because `tauri::generate_context!` embeds `dist/` at compile
  time. The Linux leg installs Tauri's system libraries (webkit2gtk et al.)
  first; Windows and macOS runners need nothing extra.
- **`lint-and-format`** job: gated by
  `if: github.event_name == 'pull_request'`, so `cargo fmt --check`,
  `cargo clippy -D warnings`, `eslint .`, and `prettier --check .` run
  **only on pull requests**. It also builds the frontend first — clippy
  compiles the Tauri shell, which needs `dist/`.
- **`coverage`** job: gated by `if: github.ref == 'refs/heads/develop'` and
  `needs: build-and-test`, so it runs **only on develop**. Generates lcov
  from both stacks — `cargo llvm-cov --workspace` and
  `vitest run --coverage` — and uploads both files to Codecov. Requires a
  `CODECOV_TOKEN` repo secret (Settings → Secrets and variables → Actions).
- **No `docs` job** — deliberate: this is a desktop application, not a
  library, so there is no API-docs site to publish (see "Adjust per
  project").

## CD behavior (encoded in the template)

`cd.yml` is the release-automation workflow. Triggers on push to `master`
that touches `package.json`.

- **`build`** job: full both-stack build + test gate — never tag a broken
  master.
- **`release`** job (`needs: build`, `permissions: contents: write`): reads
  the version from `package.json` via
  `node -p "require('./package.json').version"`, and **if that tag doesn't
  already exist**, creates + pushes `v<version>`, then merges `master` into
  `develop` (`--no-ff`). Idempotent — re-running on an unchanged version is
  a no-op.

`package.json` is the version source of truth for CD. When bumping it, bump
the `version` fields in `src-tauri/tauri.conf.json` and both crate
`Cargo.toml`s in the same commit so the app reports one version everywhere.

## Adjust per project

The templates are a strict baseline; toggle these per project:

- **bundle identifier** (`tauri.conf.json`) — the scaffold writes
  `com.example.<name>`, which Tauri warns about at build time. Replace it
  with a real reverse-DNS identifier before shipping installers.
- **icons** — `src-tauri/icons/` is generated from the placeholder
  `app-icon.png`. To brand the app, replace `app-icon.png` (square,
  1024×1024, transparency) and re-run `pnpm tauri icon app-icon.png`.
- **docs job** — omitted by design (application repo). To publish API docs
  for the core crate or the frontend, lift the `docs` job from the
  `new-rust-project` or `new-typescript-project` CI template and enable
  GitHub Pages.
- **window & CSP** (`tauri.conf.json`) — 800×600 resizable window and a CSP
  that allows inline styles (Vite injects styles inline during dev). Tighten
  or resize per app.
- **bundle targets** — `"targets": "all"` builds every installer the host OS
  supports; narrow it (e.g. `["msi"]`, `["deb", "appimage"]`) to speed up
  `pnpm tauri build`.
- **submodules** — off by default. If the repo has a `.gitmodules`, add
  `with: submodules: true` under each `actions/checkout` step that needs the
  submodule contents (at minimum `build-and-test` in `ci.yml`). Use
  `recursive` for nested submodules. Private submodules also need a PAT in
  `token:` — the default `GITHUB_TOKEN` cannot clone other private repos.

## Verify the workflow with act

Run the CI workflow locally in Docker with [act](https://github.com/nektos/act)
before pushing — when the tooling is present. First check for it:

```bash
command -v act && docker info >/dev/null 2>&1
```

If `act` is not on PATH or Docker is not running, **skip this whole
section** — it is optional validation, not a failure; state in the final
report that act verification was skipped and why. Otherwise, from the
project root:

1. `act -l` — list the jobs act resolves.
2. `act push -j build-and-test` — only the `ubuntu-latest` leg runs.
3. `act pull_request -j lint-and-format` — the PR-gated job runs.

The medium image (`catthehacker/ubuntu:act-latest`) is sufficient; pin it
non-interactively with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
Caveats: act runs Linux containers, so the `windows-latest` and
`macos-latest` matrix legs can't execute; the `coverage` job (Codecov,
develop-only) can't run under act; and
both runnable jobs `apt-get install` the webkit2gtk stack and compile the
full Tauri dependency tree inside the container, so the first run takes many
minutes — treat a timeout as "skipped", not a failure.

Report the created project path, any steps skipped because the project was
already partially set up, and the act results (or that act verification was
skipped and why).

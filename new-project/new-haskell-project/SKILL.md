---
name: new-haskell-project
description: Scaffold a new Haskell project by driving cabal init non-interactively — creates the directory and git repo with seeded commits, then cabal generates the package manifest, starter sources, test suite, CHANGELOG, and MIT license itself; the skill adds a Haskell .gitignore, README, and a GitHub Actions CI workflow that builds, tests, lints (HLint), and checks formatting (Ormolu). Also finishes a partially set-up Haskell project, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new Haskell, cabal, or GHC project, or to complete/fill in the setup of an existing one.
---

# New Haskell project (cabal)

Bootstrap a fresh Haskell package with `cabal init`. Cabal's own generator does
the heavy lifting — the `.cabal` manifest, `src/`/`app/`/`test/` starter
sources, `CHANGELOG.md`, and the MIT `LICENSE` (author and year filled from
git config) are all its output, not hand-written templates. The skill layers on
the family conventions: seeded per-step git commits, a Haskell-tuned
`.gitignore`, a README, and a GitHub Actions CI workflow.

## Inputs

- **project name** (required) — directory + cabal package name. Cabal package
  names are words of letters and digits separated by hyphens, and each
  hyphen-separated segment must contain at least one letter (`my-app` ✓,
  `my_app` ✗ — underscores are not allowed).
- **kind** — what the package builds:

  | kind                             | `cabal init` flags    | generated                          |
  | -------------------------------- | --------------------- | ---------------------------------- |
  | library + executable (default)   | `--libandexe --tests` | `src/` lib, `app/` exe, `test/`    |
  | executable                       | `--exe`               | `app/` exe only (no test suite)    |
  | library                          | `--lib --tests`       | `src/` lib, `test/`                |

  The default is the community-standard application layout: a thin
  `app/Main.hs` over a testable `src/` library. `cabal init` does not generate
  a test suite for an executable-only package (`--tests` is silently ignored
  with `--exe`); CI still works — see the no-op note below.
- **description** (optional) — one-line summary, passed as `--synopsis`.

## Tool preference

Prefer language-native tooling (`cabal init` — it generates the manifest,
sources, CHANGELOG, and LICENSE itself); use npx generators (`npx gitignore`)
where cabal has no equivalent; fall back to hand-written content only when
neither is available.

## Partially set-up projects

This skill also finishes a project that is already partially set up. Every step
is idempotent — before running a step, check whether its output already exists:

- If a `*.cabal` file already exists, skip `cabal init` (step 3) and continue
  with the remaining steps, committing any generated-but-uncommitted files as
  steps 4–6 describe.
- If the repo already has commits, skip the "New repo" empty commit.
- An artifact that already exists (LICENSE, README, workflow) is kept as-is,
  not overwritten; skip that step and its commit.
- `.gitignore` is merged, not replaced: append only the missing entries
  (including `.vscode/`).
- Only commit a step that actually changed something, keeping the same commit
  messages.

## Steps

Run from the directory where the new project folder should live. Requires
`git`, `ghc`, and `cabal` on PATH (a ghcup install is typical).

1. Create and enter (`mkdir -p` so an already-created folder is used as-is),
   then init the repo with an empty commit:

   ```bash
   mkdir -p <project name>
   cd <project name>
   git init
   git commit --allow-empty -m "New repo"
   ```

2. `.gitignore` — generate the community-standard Haskell rules
   (`dist-*` covers `dist-newstyle/`) and add the editor dir
   (`npx gitignore` appends to an existing file, so nothing is lost):

   ```bash
   npx gitignore haskell
   echo ".vscode/" >> .gitignore
   ```

   If npx is unavailable, write the same rules by hand:

   ```text
   dist
   dist-*
   cabal-dev
   *.o
   *.hi
   *.hie
   *.chi
   *.chs.h
   *.dyn_o
   *.dyn_hi
   .hpc
   .hsenv
   .cabal-sandbox/
   cabal.sandbox.config
   *.prof
   *.aux
   *.hp
   *.eventlog
   .stack-work/
   cabal.project.local
   cabal.project.local~
   .HTF/
   .ghc.environment.*
   .vscode/
   ```

   Then: `git add .gitignore && git commit -m "Added .gitignore"`

3. Generate the package. Substitute the kind flags from the table above and
   drop `--synopsis` if the user gave no description:

   ```bash
   cabal init --non-interactive --libandexe --tests \
     --package-name=<project name> \
     --license=MIT \
     --synopsis="<description>"
   ```

   Everything else stays at cabal's defaults (package version 0.1.0.0, latest
   cabal spec version, `-Wall` via a `common warnings` stanza). Author and
   maintainer are read from `git config user.name` / `user.email`; if either
   is unset, pass `--author="<name>"` and `--email="<email>"` explicitly so
   the LICENSE copyright line comes out complete. Note that cabal pins the
   `base` dependency `^>=` to the base version of the `ghc` on PATH — this is
   why step 7 pins CI to the same compiler.

   Don't commit yet — the generated files are committed in the next steps.

4. `git add LICENSE && git commit -m "Added MIT License"` (the MIT text was
   generated by `cabal init`, copyright `<year> <git user.name>`).

5. README: `echo "# <project name>" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`.

6. Commit the rest of the generated package (manifest, CHANGELOG, sources):
   `git add --all && git commit -m "Added default Cabal package"`

7. CI workflow — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml`. Replace `@GHC_VERSION@` with the output of
   `ghc --numeric-version` (e.g. `9.10.3`) — the compiler that ran
   `cabal init`, so the CI build satisfies the generated `base ^>=` bound.

   The template `uses:` pins are a current-as-of-authoring baseline and may
   have gone stale. Before committing, resolve the **latest stable major
   version** of each versioned action and update its `uses:`:

   - `actions/checkout`
   - `actions/cache` (the `restore`/`save` sub-actions share the repo's tags)
   - `haskell-actions/setup`
   - `haskell-actions/hlint-setup`
   - `haskell-actions/hlint-run`
   - `haskell-actions/run-ormolu`

   Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its
   major — `v7.0.0` → `actions/checkout@v7` (`haskell-actions/run-ormolu`
   tags plain majors like `v19`). Leave the `ghc-version`/`cabal-version`
   inputs as written — the GHC pin is the substitution above and cabal tracks
   `latest`.

   Commit: `git add --all && git commit -m "Added GitHub Actions CI workflow"`.

8. Verify the scaffold builds and tests (needs the Hackage index — run
   `cabal update` first if this machine has never done so):

   ```bash
   cabal build all && cabal test all --test-show-details=direct
   ```

   Expect `1 of 1 test suites (1 of 1 test cases) passed` — or, for the
   executable kind, `No tests to run` with exit 0. Build output lands in
   `dist-newstyle/`, which is gitignored; the working tree stays clean.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **Concurrency**: in-progress runs for the same ref are cancelled on new pushes
  to a pull request (`cancel-in-progress` only for PR events).
- **`build-and-test`** job: every trigger, across an **OS matrix**
  (`ubuntu-latest`, `windows-latest`, `fail-fast: false`).
  `haskell-actions/setup` installs the pinned GHC (the scaffold-time compiler,
  substituted at `@GHC_VERSION@`) plus the latest cabal and refreshes the
  Hackage index; then `cabal configure --enable-tests`, `cabal build all`, and
  `cabal test all`. Dependencies are cached using the pattern from the
  official `haskell-actions/setup` docs: the cabal store, keyed on
  OS + GHC + cabal versions + a hash of the build plan (`plan.json`), and
  saved right after `cabal build all --only-dependencies` — so a broken
  project build doesn't cost the dependency cache.
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so the Ormolu format check (`mode: check`, all `**/*.hs`) and HLint
  (`fail-on: warning` — suggestions only annotate, warnings and errors fail
  the job) run **only on pull requests**.
- An executable-only scaffold has no test suite; `cabal test all` prints
  `No tests to run` and exits 0, so CI stays green until real tests exist.

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
2. `act push -j build-and-test` — the build/test job; `lint-and-format` is
   skipped by the PR gate.
3. `act pull_request -j lint-and-format` — the Ormolu and HLint checks.

The medium image (`catthehacker/ubuntu:act-latest`) is sufficient; pin it
non-interactively with `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
Caveats: act runs Linux containers, so the `windows-latest` matrix leg can't
execute (expect only the `ubuntu-latest` leg), and the first `build-and-test`
run downloads and installs GHC inside the container — several GB and several
minutes before any Haskell compiles.

Report the created project path, the package kind, any steps skipped because
the project was already partially set up, and the act results (or that act
verification was skipped and why).

---
name: new-cpp-project
version: 2.1.0
description: Scaffold a new C++ project using CMake — creates the directory, git repo with seeded commits, MIT license, .gitignore, README, a CMakeLists.txt from a template (executable or library), a CMakePresets.json with dev/ci workflow presets, and a GitHub Actions CI workflow that builds, tests, lints, and checks formatting. Library scaffolds also get a Doxygen docs job deployed to GitHub Pages, a Codecov coverage job, and a CD release workflow. Also finishes a partially set-up C++ project, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new C++ or CMake project, set up a C++ executable or library, or complete/fill in the setup of an existing one.
---

# New C++ project (CMake)

Bootstrap a fresh C++ CMake project: new directory, git repo with seeded
commits, MIT license, Visual-Studio-aware `.gitignore`, README, a
`CMakeLists.txt` rendered from a bundled template — executable or library —
a `CMakePresets.json`, and a GitHub Actions CI workflow driven by those
presets. The library variant also adds a Doxygen `docs` target, a package
config with CPS and SBOM output, a GTest `test/` dir, an
`include/<name>/` header file set, docs and coverage CI jobs, and a CD
release workflow.

The executable template declares `cmake_minimum_required(VERSION 3.28...4.5)`:
3.28 is the floor (Ubuntu 24.04's CMake; FetchContent `EXCLUDE_FROM_ALL`,
`SYSTEM`, `FIND_PACKAGE_ARGS`, `block()`, header-set verification,
`CMAKE_COMPILE_WARNING_AS_ERROR`). The library template declares
`cmake_minimum_required(VERSION 4.5)` for CPS `install(PACKAGE_INFO)`,
`SemanticVersion` package compatibility, `install(SBOM)`, and Doxygen
`USES_TERMINAL`. The upper bound turns on every policy through that version
when a newer CMake runs it.

## Inputs

- **project name** (required) — directory + CMake project name.
- **kind** — executable (default) or library (if user says "library"/"lib").
- **executable name** (optional, executable only) — defaults to project name.
- **description** (optional) — project description string.

Executable name and library are mutually exclusive.

## Templates

Bundled in this skill dir. `@PROJECT_NAME@`, `@EXECUTABLE_NAME@`,
`@PROJECT_DESCRIPTION@` are placeholders to substitute by hand when noted.

- `templates/EXE_TEMPLATE_CMakeLists.txt.in`
- `templates/LIBRARY_TEMPLATE_CMakeLists.txt.in`
- `templates/PROJECT_NAMEConfig.cmake.in`
- `templates/INTERNAL_LIBRARY_MODULE_TEST_CMakeLists.txt`
- `templates/CMakePresets.json`
- `templates/.clang-format`
- `templates/ci.yml`
- `templates/LIBRARY_TEMPLATE_cd.yml`
- `reference/mit-license.txt`

## Tool preference

There is no language-native project generator for CMake, so the CMakeLists
templates above stay. For everything generic, use npx generators
(`npx gitignore`, `npx license`) and fall back to hand-written content or the
bundled reference files only when npx is unavailable.

## Partially set-up projects

This skill also finishes a project that is already partially set up. Every step
is idempotent — before running a step, check whether its output already exists:

- If the repo already has commits, skip the "New repo" empty commit.
- An artifact that already exists (LICENSE, README, `CMakeLists.txt`,
  `CMakePresets.json`, `.clang-format`, workflows, placeholder sources) is kept as-is, not
  overwritten; skip that step and its commit.
- The presets and workflows assume the template's cache options
  (`<name>_BUILD_TESTS`, `<name>_BUILD_DOCS`) and, for libraries, the
  `all_verify_interface_header_sets` target. When a pre-existing
  `CMakeLists.txt` was kept, check it defines them and report any that are
  missing rather than editing it.
- `.gitignore` is merged, not replaced: append only the missing entries
  (including `.vscode/`). If it ignores `CMakePresets.json` (an older
  version of this skill did), delete that line — the presets file is
  committed now; `CMakeUserPresets.json` is the local one to ignore.
- Only commit a step that actually changed something, keeping the same commit
  messages.

## Steps

**Commit messages are exactly the messages given below.** Never append a
`Co-Authored-By:` trailer (or any other attribution line), even if the
environment's default commit guidance says to.

Run from the directory where the new project folder should live. Requires `git`
on PATH; a CMake toolchain is needed only to build the result, not to scaffold
it.

1. Create and enter (`mkdir -p` so an already-created folder is used as-is):

   ```bash
   mkdir -p <project name>
   cd <project name>
   git init
   git commit --allow-empty -m "New repo"
   ```

2. `.gitignore` — generate the community C++ rules, then append the IDE and
   tool extras (`npx gitignore` appends to an existing file, so nothing is
   lost):

   ```bash
   npx gitignore c++
   ```

   Append:

   ```text
   # CMake build trees and per-user presets
   build/
   CMakeUserPresets.json

   # Visual Studio artifacts
   out/
   .vs/
   CMakeSettings.json

   # VS Code
   .vscode/

   # Araxis Merge artifacts
   *.orig
   ```

   If npx is unavailable, write just the appended block above. Then
   `git add .gitignore && git commit -m "Added .gitignore"`.

3. MIT license — generate it (`npx license MIT` writes `LICENSE`, filling the
   year and the author from git config):

   ```bash
   npx license MIT
   ```

   Verify the copyright line reads `Copyright (c) <current year> <git config
   user.name>` and fix it up if not. If npx is unavailable, fall back to
   `reference/mit-license.txt` with `<YEAR>` → current year followed by the
   author from `git config user.name`.
   Then `git add LICENSE && git commit -m "Added MIT License"`.

4. README: `echo "# <project name>" > README.md`, then
   `git add README.md && git commit -m "Added default README.md"`.

5. Render `CMakeLists.txt`:

   - **Executable** — read `templates/EXE_TEMPLATE_CMakeLists.txt.in`, replace
     `@PROJECT_NAME@`, `@EXECUTABLE_NAME@` (= executable name), and
     `@PROJECT_DESCRIPTION@`. Write to `CMakeLists.txt`.
   - **Library** — read `templates/LIBRARY_TEMPLATE_CMakeLists.txt.in`, replace
     `@PROJECT_NAME@` and `@PROJECT_DESCRIPTION@`. Write to `CMakeLists.txt`.

   The template's FetchContent `GIT_TAG` pins (active GoogleTest block plus
   the commented-out example dependencies) are a current-as-of-authoring
   baseline and may have gone stale. Before committing, resolve the **latest
   stable release tag** of each pinned repo and update its `GIT_TAG` — also
   inside the commented blocks, so enabling one later starts current. Unlike
   the workflow actions, FetchContent needs the full exact tag (e.g.
   `v1.17.0`), not just the major. Resolve with `git ls-remote` (no `gh`, no
   auth):

   ```bash
   git ls-remote --tags --refs https://github.com/google/googletest 'v*'
   ```

   Take the highest stable semver tag (ignore tags containing `-`). If
   `git ls-remote` is unavailable, read the tag from
   `https://github.com/<owner>/<repo>/releases/latest`.

   The `cmake_minimum_required` upper bound is likewise a baseline (`4.5` for
   executables; the library's `VERSION 4.5` has none, so its bound is the
   floor). If `cmake` is on PATH and the local `<major>.<minor>` from
   `cmake --version` is newer, write `VERSION <floor>...<local>` (never lower
   the bound, and never change the floor: `3.28` for executables, `4.5` for
   libraries). Leave it as-is when `cmake` is absent.

   Then `git add CMakeLists.txt && git commit -m "Added default CMakeLists.txt"`.

6. Presets — read `templates/CMakePresets.json`, replace every
   `@PROJECT_NAME@` with the project name, and write `CMakePresets.json`.
   Then by kind:

   - **Executable** — delete every preset named `coverage`, `docs`, or
     `ci-verify-headers` (configure, build, test, and workflow entries), and
     the `ci-verify-headers` step of the `ci` workflow preset. The executable
     template has no docs option and no header sets to verify. Keep the JSON
     valid (no trailing commas).
   - **Library** — keep every preset, and set `cmakeMinimumRequired` to
     `{ "major": 4, "minor": 5, "patch": 0 }` to match the library's
     `cmake_minimum_required` floor.

   Then `git add CMakePresets.json && git commit -m "Added CMakePresets.json"`.

   Also copy `templates/.clang-format` (Google style, 120 columns, 4-space
   indent) verbatim to `.clang-format` and commit it:
   `git add .clang-format && git commit -m "Added .clang-format"`.

7. Workflows — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml` verbatim (project-specific settings live in
   `CMakePresets.json`). Then by kind:

   - **Executable** — delete the entire `docs` and `coverage` jobs from
     `.github/workflows/ci.yml`; they only make sense for the library scaffold
     (Doxygen target, tests). Commit:
     `git add .github && git commit -m "Added GitHub Actions CI workflow"`.
   - **Library** — keep all four CI jobs, and also copy
     `templates/LIBRARY_TEMPLATE_cd.yml` to `.github/workflows/cd.yml`
     verbatim. Commit both together:
     `git add .github && git commit -m "Added GitHub Actions CI/CD workflows"`.

   The templates' `uses:` pins are a current-as-of-authoring baseline and may
   have gone stale. Before committing, resolve the **latest stable major
   version** of each versioned action present in the copied file(s) and update
   its `uses:`:

   - `actions/checkout`
   - `actions/configure-pages` (library only)
   - `actions/upload-pages-artifact` (library only)
   - `actions/deploy-pages` (library only)
   - `codecov/codecov-action` (library only)

   Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its
   major — `v6.1.0` → `actions/checkout@v6`. If `git ls-remote` is
   unavailable, read the resolved tag from
   `https://github.com/<owner>/<repo>/releases/latest`.

8. Placeholder / misc files:

   - **Executable** — `touch main.cpp`.
   - **Library**:
     - `mkdir -p include/<project name>` then
       `touch include/<project name>/<project name>.h <project name>.cpp`
     - `mkdir cmake`; render `templates/PROJECT_NAMEConfig.cmake.in` with
       `@PROJECT_NAME@` substituted → `cmake/<project name>Config.cmake.in`
       (`@PACKAGE_INIT@` stays; `configure_package_config_file` expands it).
     - `mkdir test`; copy
       `templates/INTERNAL_LIBRARY_MODULE_TEST_CMakeLists.txt` →
       `test/CMakeLists.txt` **verbatim** (uses CMake `${PROJECT_NAME}`, no
       substitution).

Leave these placeholder files uncommitted.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **Concurrency**: in-progress runs for the same ref are cancelled on new pushes
  to a pull request (`cancel-in-progress` only for PR events).
- **Presets**: every job drives CMake through `CMakePresets.json` — build
  trees land in `build/<preset>`. Workflow-level `CMAKE_BUILD_PARALLEL_LEVEL`
  (4) and an empty `CTEST_PARALLEL_LEVEL` (CTest picks the level) parallelize
  builds and tests. Locally, `cmake --workflow --preset dev` configures
  (Debug, tests on), builds, and tests.
- **`build-and-test`** job: every trigger — `cmake --workflow --preset ci`:
  configure (Release, `<project name>_BUILD_TESTS=ON`,
  `CMAKE_COMPILE_WARNING_AS_ERROR=ON` — GoogleTest is exempt), build,
  (library) build `all_verify_interface_header_sets` so every public header
  must compile on its own, then `ctest` with output on failure, across an
  **OS matrix** (`ubuntu-latest`, `windows-latest`, `fail-fast: false`). The
  test preset's `noTestsAction: ignore` keeps a project with no tests yet (the
  executable scaffold) green.
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so `clang-format --dry-run --Werror` (using the scaffolded `.clang-format`) and `clang-tidy` (default checks, against the
  `ci` preset's compile database, which includes the test sources) run
  **only on pull requests**.
- **`docs`** job (library scaffolds only): gated by
  `if: github.ref == 'refs/heads/master'` and `needs: build-and-test`, so it
  runs **only on master after build/test pass**. Installs Doxygen + Graphviz,
  runs `cmake --workflow --preset docs` (`<project name>_BUILD_DOCS=ON` turns
  on the `doxygen_add_docs` target `docs`), and deploys `build/docs/html` to
  GitHub Pages. Requires Pages enabled for the repo (Settings → Pages →
  Source: GitHub Actions).
- **`coverage`** job (library scaffolds only): gated by
  `if: github.ref == 'refs/heads/develop'` and `needs: build-and-test`, so it
  runs **only on develop**. `cmake --workflow --preset coverage` builds Debug
  with `--coverage` instrumentation and runs the tests; `gcovr` converts the
  gcov data to Cobertura XML, which is uploaded to Codecov. Requires a `CODECOV_TOKEN` repo secret (Settings →
  Secrets and variables → Actions).
- The workflow builds whatever is committed — the scaffold's placeholder
  source files are left uncommitted and empty, so CI is meaningful only once
  real sources are committed.
- Do not verify this workflow with `act` — act does not support the
  `windows-latest` runner, so it cannot exercise the build matrix's Windows
  leg. Keep **both** matrix legs (`ubuntu-latest` and `windows-latest`) and
  let GitHub-hosted runners validate the workflow.

## CD behavior (library scaffolds, encoded in the template)

`cd.yml` is the release-automation workflow. Triggers on push to `master` that
touches `CMakeLists.txt`.

- **`build`** job: `cmake --workflow --preset ci` gate — never tag a broken
  master.
- **`release`** job (`needs: build`, `permissions: contents: write`): reads the
  version from the `VERSION` line of the top-level `project()` call in
  `CMakeLists.txt` (first `VERSION <semver>` line in the file — the template
  keeps it there; fails loudly if none is found), and **if that tag doesn't
  already exist**, creates + pushes `v<version>`, then merges `master` into
  `develop` (`--no-ff`). Idempotent — re-running on an unchanged version is a
  no-op.

## Adjust per project

The templates are a strict baseline; toggle these per project:

- **`docs` and `coverage` jobs / `cd.yml`** — included for library scaffolds,
  removed for executables. For an executable that grows a public API worth
  documenting or testing to that standard, restore them from this skill's
  `templates/ci.yml` and `templates/LIBRARY_TEMPLATE_cd.yml`, the matching
  presets from `templates/CMakePresets.json`, and the docs/header-set wiring
  from `templates/LIBRARY_TEMPLATE_CMakeLists.txt.in`. Remove the
  `docs` job from a library repo with no Pages setup — without Pages enabled
  the job fails.
- **submodules** — off by default. If the repo has a `.gitmodules`, add
  `with: submodules: true` under each `actions/checkout` step that needs the
  submodule contents (at minimum `build-and-test` in `ci.yml`). Use
  `recursive` for nested submodules. Private submodules also need a PAT in
  `token:` — the default `GITHUB_TOKEN` cannot clone other private repos.

Report the created path, whether the project was scaffolded as an executable or
a library, and any steps skipped because the project was already partially set
up.

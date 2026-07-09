---
name: new-cpp-project
description: Scaffold a new C++ project using CMake — creates the directory, git repo with seeded commits, MIT license, .gitignore, README, a CMakeLists.txt from a template (executable or library), and a GitHub Actions CI workflow that builds, tests, lints, and checks formatting. Also finishes a partially set-up C++ project, adding only what's missing. Use when the user asks to start/create/initialize/bootstrap a new C++ or CMake project, set up a C++ executable or library, or complete/fill in the setup of an existing one.
---

# New C++ project (CMake)

Bootstrap a fresh C++ CMake project: new directory, git repo with seeded
commits, MIT license, Visual-Studio-aware `.gitignore`, README, a
`CMakeLists.txt` rendered from a bundled template — executable or library —
and a GitHub Actions CI workflow. The library variant also adds Doxygen
config, a package config, a GTest `test/` dir, and an `include/<name>/`
layout.

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
- `templates/LIBRARY_TEMPLATE_Doxyfile.in`
- `templates/PROJECT_NAMEConfig.cmake.in`
- `templates/INTERNAL_LIBRARY_MODULE_TEST_CMakeLists.txt`
- `templates/ci.yml`
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
- An artifact that already exists (LICENSE, README, `CMakeLists.txt`, workflow,
  placeholder sources) is kept as-is, not overwritten; skip that step and its
  commit.
- `.gitignore` is merged, not replaced: append only the missing entries
  (including `.vscode/`).
- Only commit a step that actually changed something, keeping the same commit
  messages.

## Steps

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
   # Visual Studio artifacts
   out/
   .vs/
   CMakeSettings.json
   CMakePresets.json

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

   Then `git add CMakeLists.txt && git commit -m "Added default CMakeLists.txt"`.

6. CI workflow — copy `templates/ci.yml` (this skill dir) to
   `.github/workflows/ci.yml`, replacing `@PROJECT_NAME@` with the project
   name (it appears in the configure step's `-D@PROJECT_NAME@_BUILD_TESTS=ON`
   flag).

   The template's `actions/checkout` pin (`@v6`) is a baseline and may be
   stale. Before committing, resolve the **latest stable major version** and
   update its `uses:`. Resolve with `git ls-remote` (no `gh`, no auth):

   ```bash
   git ls-remote --tags --refs https://github.com/actions/checkout 'v*'
   ```

   Take the highest stable semver (ignore tags containing `-`), pin to its
   major — `v6.1.0` → `actions/checkout@v6`. If `git ls-remote` is
   unavailable, read the resolved tag from
   `https://github.com/actions/checkout/releases/latest`.

   Commit: `git add .github && git commit -m "Added GitHub Actions CI workflow"`.

7. Placeholder / misc files:

   - **Executable** — `touch main.cpp`.
   - **Library**:
     - `mkdir -p include/<project name>` then
       `touch include/<project name>/<project name>.h <project name>.cpp`
     - Copy `templates/LIBRARY_TEMPLATE_Doxyfile.in` → `Doxyfile.in`
       **verbatim** (its `@…@` are resolved later by CMake `configure_file`).
     - `mkdir cmake`; render `templates/PROJECT_NAMEConfig.cmake.in` with
       `@PROJECT_NAME@` substituted → `cmake/<project name>Config.cmake.in`.
     - `mkdir test`; copy
       `templates/INTERNAL_LIBRARY_MODULE_TEST_CMakeLists.txt` →
       `test/CMakeLists.txt` **verbatim** (uses CMake `${PROJECT_NAME}`, no
       substitution).

These placeholder files are left uncommitted, matching the original flow.

## CI behavior (encoded in the template)

- **Triggers**: push to `master`, `develop`, `release/**`; and all pull requests.
- **Concurrency**: in-progress runs for the same ref are cancelled on new pushes
  to a pull request (`cancel-in-progress` only for PR events).
- **`build-and-test`** job: every trigger — CMake configure (Release, tests
  enabled via `-D<project name>_BUILD_TESTS=ON`), build, then
  `ctest --output-on-failure`, across an **OS matrix** (`ubuntu-latest`,
  `windows-latest`, `fail-fast: false`). `--no-tests=ignore` keeps a project
  with no tests yet (the executable scaffold) green.
- **`lint-and-format`** job: gated by `if: github.event_name == 'pull_request'`,
  so `clang-format --dry-run --Werror` (LLVM fallback style unless the project
  adds a `.clang-format`) and `clang-tidy` (default checks, against the CMake
  compile database) run **only on pull requests**.
- The workflow builds whatever is committed — the scaffold's placeholder
  source files are left uncommitted and empty, so CI is meaningful only once
  real sources are committed.
- Do not verify this workflow with `act` — act does not support the
  `windows-latest` runner, so it cannot exercise the build matrix's Windows
  leg. Keep **both** matrix legs (`ubuntu-latest` and `windows-latest`) and
  let GitHub-hosted runners validate the workflow.

Report the created path, whether the project was scaffolded as an executable or
a library, and any steps skipped because the project was already partially set
up.

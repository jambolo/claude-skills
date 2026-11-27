# 0009. C++ scaffolds commit a `CMakePresets.json`, and CI runs CMake only through it

**Status:** Accepted
**Date:** 2026-11-24
**Commits:** 7cb1c8f

## Context

Until 7cb1c8f the C++ workflows spelled out every CMake invocation, and the project name was baked into the YAML because the cache options are prefixed with it:

```yaml
- name: Configure
  run: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -D@PROJECT_NAME@_BUILD_TESTS=ON
- name: Build
  run: cmake --build build --config Release
- name: Test
  run: ctest --test-dir build --build-config Release --output-on-failure --no-tests=ignore
```

The same flags were repeated, with variations, in `build-and-test`, `lint-and-format`, `docs`, `coverage`, and the CD `build` gate, so `ci.yml` and `cd.yml` both needed `@PROJECT_NAME@` substitution, and a developer had no local command that reproduced what CI ran. Meanwhile the scaffolded `.gitignore` listed `CMakePresets.json` under "Visual Studio artifacts", treating presets as per-user IDE state.

7cb1c8f added `templates/CMakePresets.json` and a new step that renders it, and rewrote every job to call a preset:

> 6. Presets — read `templates/CMakePresets.json`, replace every `@PROJECT_NAME@` with the project name, and write `CMakePresets.json`. … Then `git add CMakePresets.json && git commit -m "Added CMakePresets.json"`.
>
> 7. Workflows — copy `templates/ci.yml` (this skill dir) to `.github/workflows/ci.yml` verbatim (project-specific settings live in `CMakePresets.json`).

> - **Presets**: every job drives CMake through `CMakePresets.json` — build trees land in `build/<preset>`. … Locally, `cmake --workflow --preset dev` configures (Debug, tests on), builds, and tests.

The file defines configure presets `dev`, `ci`, `coverage`, and `docs` over a hidden `base`, matching build and test presets, a `ci-verify-headers` build preset, and workflow presets that chain them. The `.gitignore` step swapped the entry:

> If it ignores `CMakePresets.json` (an older version of this skill did), delete that line — the presets file is committed now; `CMakeUserPresets.json` is the local one to ignore.

## Decision

`new-cpp-project` scaffolds a committed `CMakePresets.json` as the single place where build configuration lives, and commits it as its own step ("Added CMakePresets.json"). Workflows contain no CMake flags: each job runs `cmake --workflow --preset <name>` (`ci` for `build-and-test` and the CD gate, `docs`, `coverage`) or `cmake --preset ci` for the lint job's compile database. The workflow templates are therefore project-independent and copied verbatim; the project name is substituted only into the presets file. `CMakeUserPresets.json` and `build/` are ignored; `CMakePresets.json` is not. Test behavior that used to be CLI flags (`--output-on-failure`, `--no-tests=ignore`) lives in the test presets (`noTestsAction: ignore`), and parallelism is set once per workflow with `CMAKE_BUILD_PARALLEL_LEVEL` / `CTEST_PARALLEL_LEVEL`.

## Rationale

- One definition of each build configuration instead of the same flags repeated in five jobs across two workflow files.
- Local and CI builds become the same command, so a CI failure can be reproduced with `cmake --workflow --preset ci`.
- Moving the project name out of the YAML lets the workflow templates be copied verbatim, which removes a substitution step and a class of mistakes.
- Presets are the current CMake-native way to share build settings and are read by IDEs, so committing them (and ignoring only `CMakeUserPresets.json`) follows CMake's own split between shared and per-user files.

## Consequences

- `cmake --workflow --preset ci` on a developer machine runs what CI runs; `dev` is the everyday local loop.
- The presets and workflows are coupled to the template's cache options (`<name>_BUILD_TESTS`, `<name>_BUILD_DOCS`) and, for libraries, the `all_verify_interface_header_sets` target. In partial-setup mode ([0005](0005-idempotent-partial-setup-mode.md)) a kept, pre-existing `CMakeLists.txt` may not define them, so the skill checks and reports what is missing "rather than editing it".
- The kind rule ([0007](0007-publishing-jobs-follow-scaffold-kind.md)) now applies to two files: for an executable the skill deletes the `coverage`, `docs`, and `ci-verify-headers` presets as well as the `docs` and `coverage` jobs, keeping the JSON valid.
- Build trees move from `build/` to `build/<preset>`, so paths in the workflows follow (`clang-tidy -p build/ci`, Pages upload from `build/docs/html`).
- The lint job's compile database now comes from the `ci` configure preset, so `clang-tidy` sees the test sources too.
- Workflow presets require a presets-schema version and a CMake new enough to run them; the library scaffold sets `cmakeMinimumRequired` to 4.5.0 to match its `cmake_minimum_required` floor ([0010](0010-cpp-templates-target-current-cmake.md)).
- This was a breaking change to the skill's output (new step, new commit, renumbered steps, different `.gitignore`), shipped as `new-cpp-project` 2.0.0.

## Alternatives considered

- **Raw `cmake -S . -B build -D…` in each job** (ba697a6, 0707970): duplicated flags across five jobs and two workflow files, forced project-name substitution into YAML, and gave no local equivalent.
- **Treat presets as per-user state and ignore them** (the pre-7cb1c8f `.gitignore`): reversed; the per-user file is `CMakeUserPresets.json`, which is what is ignored now.

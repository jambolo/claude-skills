# 0010. C++ templates target current CMake: a 3.28 floor for executables, 4.5 for libraries, built-in features over hand-rolled ones

**Status:** Accepted
**Date:** 2026-11-24
**Commits:** 7cb1c8f

## Context

The original `CMakeLists.txt` templates declared `cmake_minimum_required(VERSION 3.23)` and worked around what that version lacked: explicit `cmake_policy(SET CMP0077 NEW)` / `CMP0135` lines, a hand-computed `IS_TOP_LEVEL_PROJECT`, a 2,951-line `LIBRARY_TEMPLATE_Doxyfile.in` run through `configure_file`, docs switched on by a `<name>_DOXYGEN_OUTPUT_DIRECTORY` path option, and a package config file that set a `<name>_LIBRARIES` variable.

7cb1c8f ("Added the latest bells and whistles to the CMakeLists.txt templates (minimum version is 4.5)") rewrote both templates against current CMake and recorded why each floor is where it is:

> The executable template declares `cmake_minimum_required(VERSION 3.28...4.5)`: 3.28 is the floor (Ubuntu 24.04's CMake; FetchContent `EXCLUDE_FROM_ALL`, `SYSTEM`, `FIND_PACKAGE_ARGS`, `block()`, header-set verification, `CMAKE_COMPILE_WARNING_AS_ERROR`). The library template declares `cmake_minimum_required(VERSION 4.5)` for CPS `install(PACKAGE_INFO)`, `SemanticVersion` package compatibility, `install(SBOM)`, and Doxygen `USES_TERMINAL`. The upper bound turns on every policy through that version when a newer CMake runs it.

The upper bound is treated like the other template pins:

> The `cmake_minimum_required` upper bound is likewise a baseline … If `cmake` is on PATH and the local `<major>.<minor>` from `cmake --version` is newer, write `VERSION <floor>...<local>` (never lower the bound, and never change the floor: `3.28` for executables, `4.5` for libraries). Leave it as-is when `cmake` is absent.

## Decision

The C++ templates are written for current CMake and prefer a built-in feature to a hand-rolled equivalent, accepting a high version floor as the price:

- **Floors differ by kind.** Executables: `3.28...4.5`, so the scaffold configures on a stock Ubuntu 24.04 runner. Libraries: `4.5`, because the packaging features they ship need it. The floor is fixed by the template's feature use; only the policy upper bound is refreshed at scaffold time, from the local `cmake`.
- **Policies by version range**, not individual `cmake_policy(SET …)` lines; `PROJECT_IS_TOP_LEVEL` instead of a computed flag.
- **Dependencies** are declared with FetchContent `EXCLUDE_FROM_ALL SYSTEM FIND_PACKAGE_ARGS`, so an installed package is used when present and fetched otherwise.
- **Warnings are errors in CI only** (`CMAKE_COMPILE_WARNING_AS_ERROR=ON` in the `ci` preset), and third-party code is exempted with a `block()` around `FetchContent_MakeAvailable`.
- **Public headers are a `FILE_SET HEADERS`** with `VERIFY_INTERFACE_HEADER_SETS`, and CI builds `all_verify_interface_header_sets` so every public header must compile on its own.
- **Docs are a `doxygen_add_docs` target** configured by `DOXYGEN_*` variables in `CMakeLists.txt` and enabled by a boolean `<name>_BUILD_DOCS`; the bundled `Doxyfile.in` is deleted.
- **Library installs are complete packages**: `configure_package_config_file` with `@PACKAGE_INIT@` and `check_required_components`, a `SemanticVersion` version file, a CPS description (`install(PACKAGE_INFO)`), and an SPDX SBOM (`install(SBOM)`), all behind a `<name>_INSTALL` option that defaults off when the project is consumed as a subproject.

## Rationale

- 3.28 is the executable floor because it is what Ubuntu 24.04 ships and is the first version with every feature the template uses; 4.5 is the library floor because CPS export, `SemanticVersion`, `install(SBOM)`, and Doxygen `USES_TERMINAL` need it; the upper bound exists to turn on newer policies.
- A new project has no legacy consumers, so a scaffold should start from current best practice rather than the lowest common denominator; the author wants the newest CMake features in new projects.

## Consequences

- A scaffolded library does not configure with the CMake most distributions and GitHub runners ship today; whoever builds it (including its consumers via `add_subdirectory` or FetchContent) needs CMake 4.5 or newer. An executable scaffold has no such requirement.
- The skill directory lost its largest file and the library scaffold no longer has a `Doxyfile.in` to copy; Doxygen settings are a dozen `set(DOXYGEN_…)` lines that sit next to the target they configure.
- Cache option names changed (`<name>_DOXYGEN_OUTPUT_DIRECTORY` → `<name>_BUILD_DOCS`; new `<name>_INSTALL`), which is part of why the change shipped as `new-cpp-project` 2.0.0 and why the presets ([0009](0009-cpp-builds-are-driven-by-a-committed-cmakepresets-json.md)) depend on the template's options.
- `SemanticVersion` treats `0.y` releases as mutually incompatible, so a consumer's `find_package(<name> 0.1)` will not accept `0.2`; the template says so in a comment.
- The refresh rule in [0002](0002-template-pins-are-a-baseline-refreshed-at-scaffold-time.md) gains a pin with a different source of truth: the local toolchain, raise-only, optional when `cmake` is absent.
- The templates will age against CMake itself; the next modernization is a template edit plus a decision about whether either floor moves.

## Alternatives considered

- **Stay on a 3.23 floor with workarounds** (646403b through 0707970): portable to older CMake, but kept explicit policy lines, a vendored Doxyfile, and no CPS/SBOM output.
- **One floor for both kinds**: 4.5 everywhere would put an unnecessary requirement on executables, which use nothing newer than 3.28; 3.28 everywhere would drop the library's packaging features.
- **Vendored `Doxyfile.in`** (0707970): replaced by `doxygen_add_docs`, which generates the Doxyfile from variables.

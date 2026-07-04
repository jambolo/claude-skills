---
name: new-cpp-project
description: Scaffold a new C++ project using CMake — creates the directory, git repo with seeded commits, MIT license, .gitignore, README, and a CMakeLists.txt from a template (executable or library). Use when the user asks to start/create/initialize/bootstrap a new C++ or CMake project, or set up a C++ executable or library.
---

# New C++ project (CMake)

Bootstrap a fresh C++ CMake project: new directory, git repo with seeded
commits, MIT license, Visual-Studio-aware `.gitignore`, README, and a
`CMakeLists.txt` rendered from a bundled template — executable or library. The
library variant also adds Doxygen config, a package config, a GTest `test/`
dir, and an `include/<name>/` layout.

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
- `reference/mit-license.txt`

## Steps

Run from the directory where the new project folder should live. Requires `git`
and `cmake`-targeting toolchain on PATH (git only for scaffolding).

1. Create and enter:

   ```bash
   mkdir <project name>
   cd <project name>
   git init
   git commit --allow-empty -m "New repo"
   ```

2. Write `.gitignore`, then `git add .gitignore && git commit -m "Added .gitignore"`:

   ```text
   # Visual Studio artifacts
   out/
   .vs/
   CMakeSettings.json
   CMakePresets.json

   # Araxis Merge artifacts
   *.orig
   ```

3. Write `LICENSE` from `reference/mit-license.txt` with `<YEAR>` → current year.
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

6. Placeholder / misc files:

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

Report the created path and whether it was built as an executable or library.

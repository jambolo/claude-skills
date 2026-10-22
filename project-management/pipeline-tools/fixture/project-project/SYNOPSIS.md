# notes — project synopsis

Build `notes`, a bash command-line tool that keeps one-line notes in a text file. This
synopsis is the complete interview input: everything a project plan needs is stated
here, and anything it does not state is out of scope.

## What is built and why
Three scripts and a test runner, so a user can add, list, and search short notes from
the shell. It exists to exercise the planning pipeline end to end at low cost.

## Environment, language, stack
- bash and coreutils only (`grep`, `sed`, `awk`, `wc`, `printf`); no other languages,
  no package managers, no network.
- Every script's first line is `#!/usr/bin/env bash`; scripts are run as
  `bash src/<name>.sh ...` from the repository root and are not executable by file mode.
- The notes file is the path in `NOTES_FILE` when that variable is set, else `.notes` in
  the current directory; one note per line, newest last. Tests set `NOTES_FILE` to a
  temporary file so they never touch a real one.

## Structure and components
- `src/add.sh <text>` — appends one note; prints nothing; exits 0.
- `src/list.sh` — prints every note as `<n>: <note>`, numbered from 1 in file order; an
  absent or empty notes file prints nothing and exits 0.
- `src/search.sh <substring>` — prints the lines `list.sh` would print, filtered to notes
  containing the substring case-insensitively; no match prints nothing and exits 0.
- `test/run.sh` — runs the scripts against a temporary notes file and prints exactly `ok`
  (exit 0) or `fail` (exit 1).
- `README.md` keeps its title and paragraph; a `## Usage` section is appended.

## Techniques
Plain bash string handling and `printf`; `grep -n -i` for search; no `eval`, no
temporary files other than the test's notes file.

## Constraints
- Exact output formats as above: no trailing whitespace, no extra lines.
- A missing argument to `add.sh` or `search.sh` prints one usage line on stderr and
  exits 1.
- Notes may contain spaces and `#`; they are stored and printed verbatim.

## Out of scope
Editing or deleting notes, multiple notes files, locking, configuration, man pages.

## Definition of Done (project)
Run from the repository root with `NOTES_FILE=/tmp/notes-dod`, starting from no file:
- `bash src/add.sh "buy milk"; bash src/add.sh "call Bob"; wc -l < "$NOTES_FILE"` → `2`
- `bash src/list.sh` → `1: buy milk` then `2: call Bob`
- `bash src/search.sh bob` → `2: call Bob`
- `bash test/run.sh` → `ok`
- `grep -c '^## Usage' README.md` → `1`

## Milestones, in order
1. **add-list** — `src/add.sh`, `src/list.sh`, and `test/run.sh` covering both.
   Done when the add and list items of the project Definition of Done pass and
   `bash test/run.sh` prints `ok`. Depends on nothing.
2. **search-docs** — `src/search.sh`, `test/run.sh` extended to cover it, and the README
   `## Usage` section. Done when the whole project Definition of Done passes. Depends on
   milestone 1.

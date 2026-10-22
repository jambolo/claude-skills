# textstat — Brief

## Goal
Build `textstat`, a bash command-line tool that reports word count, line count, and the
most frequent words of a text file, with a test suite and usage documentation. The goal
is sized to exercise the full pipeline — decomposition, parallel workers, a judgment
step, verification, and three phase gates — in a run that costs little.

## Context
- Repository: a bash project with no build step. `README.md` exists at the root with a
  title and one paragraph. `samples/sample.txt` holds two lines:
  `the cat sat on the mat` and `the dog sat on the log` (12 words, 2 lines; "the"
  occurs 4 times, "sat" and "on" twice each, every other word once).
- Scripts live in `src/`, are run as `bash src/<name>.sh ...` from the repository root,
  and are not executable by file mode. Tests live in `test/run.sh`, run as
  `bash test/run.sh` from the root, printing exactly `ok` on success (exit 0) or `fail`
  (exit 1).
- A **word** is a maximal run of non-whitespace characters, compared case-insensitively
  (lowercase before counting). Punctuation is not stripped.
- Every script's first line is `#!/usr/bin/env bash`. Use only bash, coreutils, `sort`,
  `uniq`, `tr`, `awk`, `grep`, `wc`.
- Output formats are exact (no trailing whitespace, one value per line):
  - `src/wc.sh <file>` prints the word count as a bare integer.
  - `src/lines.sh <file>` prints the line count as a bare integer.
  - `src/freq.sh <N> <file>` prints the N most frequent words, one per line, as
    `<word> <count>`, most frequent first.
  - `src/textstat.sh wc|lines|freq [N] <file>` dispatches to the scripts above with the
    same output; `src/textstat.sh --help` prints usage, whose first line is exactly
    `usage: textstat.sh <wc|lines|freq [N]> <file>`.

## Constraints
- bash only; no other languages, no package managers, no network.
- Every script's first line is `#!/usr/bin/env bash`; every script exits non-zero with a
  one-line message on stderr when given a missing file.
- `README.md` keeps its existing title and paragraph; new content is appended.

## Assumptions
- `bash`, `git`, and GNU or BSD coreutils are on PATH.

## Out of scope
- Locale-aware case folding, Unicode normalization, stemming, stop words,
  configuration files, man pages.

## Definition of Done (project)
```dod
# wc counts words
cmd: bash src/wc.sh samples/sample.txt
expect: 12
# lines counts lines
cmd: bash src/lines.sh samples/sample.txt
expect: 2
# freq ranks the top word
cmd: bash src/freq.sh 1 samples/sample.txt
expect: the 4
# dispatcher routes wc
cmd: bash src/textstat.sh wc samples/sample.txt
expect: 12
# help first line
cmd: bash src/textstat.sh --help | head -n 1
expect: usage: textstat.sh <wc|lines|freq [N]> <file>
# test suite passes
cmd: bash test/run.sh
expect: ok
# README documents usage
cmd: grep -c '^## Usage' README.md
expect: 1
# README documents the tie-break rule
cmd: grep -qi 'tie' README.md && echo yes
expect: yes
```

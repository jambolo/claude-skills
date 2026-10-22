# textstat — Roadmap

Phase 1 builds the three independent scripts in parallel; phase 2 adds the dispatcher
and the test suite on top of them and settles the one open design decision; phase 3
documents the tool and adds `--help`.

## Phase 1 — Core scripts
- **Objective:** `src/wc.sh`, `src/lines.sh`, and `src/freq.sh` exist, follow the
  brief's formats, and reject a missing file with a one-line stderr message and a
  non-zero exit.
- **Scope:** `src/`
- **Depends on:** nothing
- **Definition of Done (phase):**
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
  # freq rejects a missing file
  cmd: bash src/freq.sh 1 samples/missing.txt >/dev/null 2>&1; echo $?
  expect: 1
  ```
- **Risks:** word splitting and case folding must match the brief exactly; the
  tie-break order among equal counts is deliberately left open until phase 2.

## Phase 2 — Dispatcher, tests, tie-break decision
- **Objective:** `src/textstat.sh` dispatches `wc`, `lines`, and `freq [N]` to the phase 1
  scripts; `test/run.sh` exercises every command against `samples/sample.txt` and prints
  `ok`; the tie-break rule for equal frequencies (alphabetical, or first occurrence in
  the input) is decided, implemented in `src/freq.sh`, and stated in one sentence
  appended to `README.md` under a `## Tie-break rule` heading. The choice is open: pick
  the rule a user of a word-frequency tool would least be surprised by, and say why.
- **Scope:** `src/textstat.sh`, `src/freq.sh`, `test/`, `README.md`
- **Depends on:** phase 1
- **Definition of Done (phase):**
  ```dod
  # dispatcher routes wc
  cmd: bash src/textstat.sh wc samples/sample.txt
  expect: 12
  # dispatcher routes freq with N
  cmd: bash src/textstat.sh freq 1 samples/sample.txt
  expect: the 4
  # ties are ordered deterministically
  cmd: bash src/freq.sh 3 samples/sample.txt | tail -n 2 | sort | tr '\n' ' ' | sed 's/ $//'
  expect: on 2 sat 2
  # test suite passes
  cmd: bash test/run.sh
  expect: ok
  # README states the tie-break rule
  cmd: grep -c '^## Tie-break rule' README.md
  expect: 1
  ```
- **Risks:** the tie-break item needs a decision, not a lookup — expect a `judgment`
  route; `src/freq.sh` is edited in this phase and must not run in parallel with
  anything else touching it.

## Phase 3 — Help and documentation
- **Objective:** `src/textstat.sh --help` prints usage whose first line is exactly
  `usage: textstat.sh <wc|lines|freq [N]> <file>`; `README.md` gains a `## Usage` section
  showing each command; the test suite still passes.
- **Scope:** `src/textstat.sh`, `README.md`
- **Depends on:** phase 2
- **Definition of Done (phase):**
  ```dod
  # help first line
  cmd: bash src/textstat.sh --help | head -n 1
  expect: usage: textstat.sh <wc|lines|freq [N]> <file>
  # README documents usage
  cmd: grep -c '^## Usage' README.md
  expect: 1
  # test suite still passes
  cmd: bash test/run.sh
  expect: ok
  ```
- **Risks:** none beyond keeping the README's existing content intact.

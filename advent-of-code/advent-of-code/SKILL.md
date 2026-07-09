---
name: advent-of-code
description: >
  Manages Advent of Code projects across any language. Use this skill whenever
  the user mentions Advent of Code, AoC, puzzle solutions, or working on a
  specific day/year/part. Handles four operations:
  (1) init — generate or update CLAUDE.md with project-specific process
      documentation tailored to the language and environment;
  (2) scaffold — bootstrap a new AoC project, delegating repo setup to the
      matching new-<language>-project skill (new-rust-project,
      new-cpp-project, new-typescript-project, new-julia-project,
      new-haskell-project) when one exists, then layering on an AoC-specific
      structure researched from community practice for that language;
  (3) stub — add a stub for a new day to an existing project;
  (4) run — execute a day's solution and verify its output against the answers
      in README.md.
  Trigger any time the user says things like "set up my AoC project",
  "add day 5", "run day 3 part 2", "scaffold advent of code", "check my
  answer", "create CLAUDE.md for my AoC repo", or similar. For a new
  non-AoC project in one of those languages, use the new-<language>-project
  skill directly instead.
---

# Advent of Code Skill

## Overview

This skill helps Claude work effectively on Advent of Code projects in any
programming language. The four operations can be combined in a single request
(e.g., "scaffold a new Rust AoC 2024 project and add a stub for day 1").

The scaffold operation is built on top of the `new-<language>-project`
scaffolder skills: when the project's language has one, that skill does the
repo bootstrap (git history, .gitignore, license, README, build config, CI)
and this skill only adds what is AoC-specific. Do not reimplement anything a
scaffolder skill already does.

---

## The AoC project contract

Every project this skill manages satisfies the same contract, regardless of
language. It is stated once, here; the operations below reference it instead
of restating it, and generated CLAUDE.md files document only how the project
*realizes* it (exact commands, paths, types) plus any deviations.

- **Structure** — a shared common library plus one runnable entry point per
  day. Days are independent: the common library is the only cross-day code.
- **Flags** — every day accepts `--part <1|2>` (default 1) and `--example`
  (read `example.txt` instead of `input.txt`).
- **Output** — each run prints the banner `=== Day <N>, part <P> ===` and
  emits its answer as the last line of stdout in the form `Answer: <value>`.
- **Answers** — README.md contains one section per day:

  ```markdown
  ## Day <N>

  | Part | Answer |
  |-----:|-------:|
  |    1 |        |
  |    2 |        |
  ```

  A blank answer cell means that part is not yet solved.

---

## Step 0 — Orient yourself before acting

The right first move depends on the operation. The guiding principle is:
**read the project before asking the user**. Everything Claude needs for
stub and run operations is already encoded in the project — in CLAUDE.md,
in the existing day directories, in the build files. Only init and scaffold
genuinely need upfront user input.

### For stub and run operations

**Read CLAUDE.md first.** It contains the language, build system, run
commands, directory layout, common library API, naming conventions, and
input file locations. Do not ask the user for any of this — derive it from
the file. If CLAUDE.md doesn't exist or is missing a critical piece (e.g.,
the run command), inspect the project files to infer it (look at existing
day directories, build configs, etc.), then ask only about what truly cannot
be determined.

The only input you may need from the user for these operations is **the day
number** — and even that is usually in the request ("add day 7", "run day 3").

### For init and scaffold operations

These create a project from scratch, so you do need some upfront information.
Extract what you can from the user's message; ask once for what's missing:

| Input | Why it matters |
| --- | --- |
| **Language & environment** | Selects the bootstrap skill, build system, file layout, run commands |
| **Year** | Goes into project name and README header |
| **Operation(s)** | init / scaffold / stub / run (may be combined) |

Ask for missing inputs in a single, short message — don't make the user answer
multiple questions. Example:
> "Which language/runtime and which year? I'll scaffold the project and
> generate CLAUDE.md from there."

---

## Operation 1 — Init (generate/update CLAUDE.md)

CLAUDE.md teaches Claude how to work on *this specific project*. It should be
at the project root and cover everything a developer (or Claude) needs to
navigate the codebase from a cold start.

CLAUDE.md records **project facts** — commands, paths, types, APIs,
conventions. It must not restate **operation procedure** (how to stub, run,
verify) or **contract semantics** (flag meanings, banner and answer formats,
the days-independent rule) — those live in this skill and would drift in
per-repo copies. Two-sided test: would the sentence be identical in every
AoC project? It belongs in this skill. Does it mention a tool, file, type,
or command of this repo? It belongs in CLAUDE.md.

### What to include

**Project identity**

- Language, runtime version, build system
- Year, and what "Advent of Code" is (one sentence)
- How the repo was bootstrapped, in one line (e.g., "bootstrapped via
  new-rust-project" or "inline; no language skill, no CI") — don't
  enumerate the bootstrap artifacts

**Repository layout** — describe the actual directory tree:

```text
<project-root>/
├── CLAUDE.md
├── README.md
├── LICENSE
├── <common-lib>/      # shared setup + data-loading utilities
└── day<NN>/           # one per day (or equivalent for the language)
```

**How to add a new day** — language-specific steps:

- Copy the stub / scaffold command / template
- Wire it into any dispatch mechanism if monolithic
- Name conventions (e.g., `day01`, `day_01`, `Day01`)

List only the steps specific to this project (what to copy, what to rename,
what to register in the build config). Omit the generic stub requirements
(banner, placeholder solvers, empty input files, README section) —
Operation 3 owns those.

**How to build and run a day**

- Exact shell commands from the project root, including how the contract
  flags are passed (e.g., after `--` for cargo/cabal) — the realization is
  project-specific even though the flag semantics are contract
- Any deviations from the contract's flag/banner/answer-output behavior; if
  the project follows the contract exactly, say nothing about those

**Common library API** — document the functions a new day's code will call:

- Setup / argument parsing (returns day, part, input filename)
- Data loaders: single string, line-by-line, comma-separated numbers,
  character grid, number grid

**Answer locations** — only if the project deviates from the contract
(answers kept somewhere other than the README day tables, or a different
stdout signal). If the project follows the contract, omit this section
entirely. Never describe the verify procedure itself — that is Operation 4.

**Conventions**

- Where puzzle input files live (e.g., `day01/input.txt`, `day01/example.txt`)
- File naming, function/struct naming patterns

### Language-specific guidance

Adapt everything to the actual language. For an existing project, the layout
and run command are facts to read out of the repo, not choices to make. For a
brand-new project, they come from the structure research done during scaffold
(see Operation 2, Phase B) — CLAUDE.md should document the chosen structure
*and* cite where it came from, so later sessions don't re-derive or
second-guess it.

If the user hasn't specified how the contract flags reach the program (e.g.,
after `--`, via a runner script), propose a reasonable convention for the
language and document it.

### Updating an existing CLAUDE.md

If CLAUDE.md already exists, read it first. Preserve all sections that are
still accurate. Add or overwrite only what has changed (e.g., new day, changed
build command). Don't rewrite sections that are fine. While updating, delete
any prose that restates skill operation procedure (see the facts-vs-procedure
rule above).

---

## Operation 2 — Scaffold project

Create the full initial project structure for a new AoC year. This happens in
two phases: **bootstrap** (generic repo setup) and **AoC layer** (everything
specific to Advent of Code). Keep the per-step commit discipline throughout —
the seeded git history is intentional output.

### Phase A — Bootstrap the repository

Check whether a `new-<language>-project` skill exists for the project's
language. If it does, **invoke it via the Skill tool** — do not replicate its
steps by hand. It produces the git repo with seeded commits, .gitignore, MIT
license, starter README, build config, and (where the skill provides one) a
CI workflow.

| Language | Bootstrap skill | Notes for the delegated run |
| --- | --- | --- |
| Rust | `new-rust-project` | Project name = AoC repo name (e.g., `advent-of-code-2024`). AoC repos are binary-only with no Pages, Codecov, or releases: skip `cd.yml` and remove the `docs` and `coverage` CI jobs unless the user asks for them. |
| C++ | `new-cpp-project` | Use the **executable** variant. |
| TypeScript | `new-typescript-project` | Operates in the current directory — `mkdir` the project folder and `cd` in first. Pass through the user's npm/pnpm choice (ask if unstated, as that skill requires). |
| Julia | `new-julia-project` | Package name must be a valid Julia identifier (e.g., `AdventOfCode2024`). |
| Haskell | `new-haskell-project` | Hyphenated names are fine (`advent-of-code-2024`). Use the default **library + executable** kind — days become further executables over the shared library. |

For any other language, bootstrap inline, matching the same conventions the
scaffolder skills share:

1. `git init`, then `git commit --allow-empty -m "New repo"`
2. Language-appropriate `.gitignore` — commit
3. MIT license, `Copyright (c) <current year> John Bolton` — commit
4. `README.md` containing only `# <project name>` — commit
5. Build configuration (`go.mod`, `Makefile`, etc.) — commit

### Phase B — AoC layer

On top of the bootstrapped repo, add the AoC-specific content. One commit per
step.

1. **Research the structure, then restructure.** The bootstrap skills produce
   a single-target project; an AoC project needs a common library plus one
   entry point per day. **Do not hardcode the layout, guess from general
   principles, or ask the user to design it** — research how the AoC
   community actually structures projects in this language, then adopt the
   prevailing convention.

   Research (WebSearch / WebFetch):

   - Search for AoC repos and templates in the language (e.g.
     `advent of code <language> project structure`, GitHub topic
     `advent-of-code` filtered by language, the awesome-advent-of-code list).
     Prefer well-starred templates and repos from people who have completed
     multiple years — they encode lessons a fresh design won't have.
   - Check for language-specific AoC tooling that dictates structure (e.g.
     `cargo-aoc` for Rust, AoC runner packages on npm/PyPI). If a dominant
     tool exists, weigh adopting its layout against rolling a plain one.
   - Identify the prevailing pattern: how days are separated (crate / package
     / module / script per day), where shared utilities live, where inputs
     are stored, how a single day is invoked.

   Then choose the structure that best matches community practice **while
   still satisfying the contract** (see "The AoC project contract" above)
   and staying compatible with what the bootstrap skill already set up
   (toolchain config, CI). If community practice conflicts with the contract
   on some point, keep the contract and note the deviation in CLAUDE.md.

   Record in CLAUDE.md (Operation 1) which sources informed the structure and
   why it was chosen, so later sessions reuse the decision instead of
   re-researching it.

2. **Rewrite `README.md`** (overwriting the bootstrap placeholder), then
   commit:

   ```markdown
   # Advent Of Code <year>

   My solutions for Advent of Code <year> implemented with <language and environment>
   ```

   followed by a `## Day 1` section in the contract's answer-table format,
   with a `<placeholder for implementation notes>` line between the heading
   and the table.

3. **Common library** — language-appropriate module/package with:

   - Argument parsing implementing the contract's flags and banner; returns
     day number, part, and the input filename
   - Data loaders for: single string, lines, comma-separated integers,
     character grid (`Vec<Vec<char>>` / `list[list[str]]` / etc.),
     integer grid

4. **Stub for day 1** — follow Operation 3 for day 1.

5. **CI fix-up** — if the bootstrap skill installed a CI workflow, make sure
   it still passes against the restructured layout (e.g., workspace-wide
   `cargo build`/`cargo test` instead of a single crate). If the language had
   no bootstrap skill, CI is optional — add it only if the user asks.

6. **`CLAUDE.md`** — follow Operation 1. Record the bootstrap skill used
   (one line, per Operation 1's project identity) so later operations know
   where the repo conventions came from.

### Goal: working from the start

After scaffolding, `run day 1 part 1` (or equivalent) should succeed and
print the banner. It doesn't need to solve anything — it just needs to run.

---

## Operation 3 — Add a day stub

Add a new day to an existing project. Orient per Step 0 (read CLAUDE.md
first), then inspect one or two existing day directories to confirm the
exact code patterns in use. The stub
must be indistinguishable in style from the existing days — a newcomer to the
project should not be able to tell which day was added by Claude.

The stub should:

- Follow the exact naming and layout conventions already in use (inspect the
  existing day directories to match style)
- Import and call the common library's setup function
- Print the banner via the common library
- Have placeholder `solve_part1()` and `solve_part2()` functions (or
  equivalent) that return `None` / `0` / empty string — whatever the language
  convention is
- Include `input.txt` and `example.txt` as empty files in the day directory
- Be wired into the build system (add to workspace `Cargo.toml`, `go.mod`,
  `CMakeLists.txt`, etc.)

Add the corresponding `## Day <N>` section to README.md, in the contract's
answer-table format (blank cells).

---

## Operation 4 — Run and verify

Run a day's solution and compare the output to the answers in README.md.
Orient per Step 0: the run command, working directory, and any contract
deviations come from CLAUDE.md — or, failing that, from the build files and
existing day code. Where CLAUDE.md is silent, the contract formats apply.

### Steps

1. **Read CLAUDE.md** — extract the run command template and any contract
   deviations.

2. **Read README.md** — parse the requested day's answer table (contract
   format); extract the expected answers for parts 1 and 2 (a blank cell
   means not yet solved).

3. **Run part 1**, capture stdout. Take the answer per the contract unless
   CLAUDE.md notes a different signal.

4. **Run part 2**, same approach.

5. **Report results** in a compact table:

   | Part | Expected | Got | ✓/✗ |
   | ---: | ---: | ---: | --- |
   | 1 | 12345 | 12345 | ✓ |
   | 2 | 67890 | 67890 | ✓ |

6. If an expected answer is blank (not yet in README.md), report the output
   and ask whether to write it to README.md.

7. If the output doesn't match, show the full stdout to help debug.

If the user asks for the example run or a single part, pass the contract
flags (`--example`, `--part <N>`) accordingly.

---

## Common pitfalls to avoid

These add to the rules already stated in the contract and operations above —
they don't repeat them.

- **Don't clobber existing work.** Before writing any file, check whether it
  exists. For CLAUDE.md, merge rather than overwrite. For README.md day
  sections, append rather than replace. (The scaffold-time README rewrite of
  the bootstrap placeholder is the one intentional exception.)
- **Don't invent answers.** When running, capture actual process output —
  don't guess or synthesize the answer.

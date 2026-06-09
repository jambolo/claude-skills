---
name: advent-of-code
description: >
  Manages Advent of Code projects across any language. Use this skill whenever
  the user mentions Advent of Code, AoC, puzzle solutions, or working on a
  specific day/year/part. Handles four operations:
  (1) init — generate or update CLAUDE.md with project-specific process
      documentation tailored to the language and environment;
  (2) scaffold — create the full project directory structure and starter files
      for a new year or a new day;
  (3) stub — add a stub for a new day to an existing project;
  (4) run — execute a day's solution and verify its output against the answers
      in README.md.
  Trigger any time the user says things like "set up my AoC project",
  "add day 5", "run day 3 part 2", "scaffold advent of code", "check my
  answer", "create CLAUDE.md for my AoC repo", or similar.
---

# Advent of Code Skill

## Overview

This skill helps Claude work effectively on Advent of Code projects in any
programming language. The four operations can be combined in a single request
(e.g., "scaffold a new Rust AoC 2024 project and add a stub for day 1").

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
|-------|---------------|
| **Language & environment** | Determines build system, file layout, run commands, common library patterns |
| **Year** | Goes into project name, README header, LICENSE copyright |
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

### What to include

**Project identity**
- Language, runtime version, build system
- Year, and what "Advent of Code" is (one sentence)

**Repository layout** — describe the actual directory tree:
```
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

**How to build and run a day**
- Exact shell commands from the project root
- How `<part>` and `<example>` flags are passed
- What the banner output looks like (`=== Day <N>, part <P> ===`)

**Common library API** — document the functions a new day's code will call:
- Setup / argument parsing (returns day, part, input filename)
- Data loaders: single string, line-by-line, comma-separated numbers,
  character grid, number grid

**How to verify answers** — point to README.md table format and explain the
`run` operation (see Operation 4).

**Conventions**
- Where puzzle input files live (e.g., `day01/input.txt`, `day01/example.txt`)
- File naming, function/struct naming patterns
- How to handle "example" vs. "real" input

### Language-specific guidance

Adapt everything to the actual language. Examples:

| Language | Typical layout | Run command |
|----------|---------------|-------------|
| Rust | Cargo workspace, one crate per day | `cargo run -p day01 -- --part 1` |
| Python | One script per day | `python day01/day01.py --part 1` |
| Go | Module with one package per day | `go run ./day01 --part 1` |
| C/C++ | CMake or Makefile, one binary per day | `./build/day01 --part 1` |
| Haskell | Cabal/Stack project | `cabal run day01 -- --part 1` |
| TypeScript/Node | npm workspace | `npx ts-node day01/index.ts --part 1` |

If the user hasn't specified how arguments are passed, propose a reasonable
convention for the language and document it.

### Updating an existing CLAUDE.md

If CLAUDE.md already exists, read it first. Preserve all sections that are
still accurate. Add or overwrite only what has changed (e.g., new day, changed
build command). Don't rewrite sections that are fine.

---

## Operation 2 — Scaffold project

Create the full initial project structure for a new AoC year. This goes
beyond the directory tree — it creates real, runnable starter files.

### Always create

1. **`README.md`** — use this exact structure:
   ```markdown
   # Advent Of Code <year>

   My solutions for Advent of Code <year> implemented with <language and environment>

   ## Day 1

   <placeholder for implementation notes>

   | Part | Answer |
   |-----:|-------:|
   |    1 |        |
   |    2 |        |
   ```

2. **`LICENSE`** — MIT license, `Copyright (c) <year> John Bolton`

3. **Common library** — language-appropriate module/package with:
   - Argument parsing: reads `--part <1|2>` and `--example` from argv,
     prints `=== Day <N>, part <P> ===` banner, returns day number, part,
     and the input filename (`input.txt` or `example.txt`)
   - Data loaders for: single string, lines, comma-separated integers,
     character grid (`Vec<Vec<char>>` / `list[list[str]]` / etc.),
     integer grid

4. **Stub for day 1** — follow Operation 3 for day 1

5. **Build configuration** — `Cargo.toml` / `go.mod` / `package.json` /
   `CMakeLists.txt` etc. as appropriate, wired up to include the common
   library and day 1

6. **`CLAUDE.md`** — follow Operation 1

### Goal: working from the start

After scaffolding, `run day 1 part 1` (or equivalent) should succeed and
print the banner. It doesn't need to solve anything — it just needs to run.

---

## Operation 3 — Add a day stub

Add a new day to an existing project. **Start by reading CLAUDE.md** to
learn the language, directory layout, naming conventions, common library
import path, build system, and input file locations. Then inspect one or two
existing day directories to confirm the exact code patterns in use. The stub
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

Add a corresponding section to README.md:
```markdown
## Day <N>

| Part | Answer |
|-----:|-------:|
|    1 |        |
|    2 |        |
```

---

## Operation 4 — Run and verify

Run a day's solution and compare the output to the answers in README.md.
**Start by reading CLAUDE.md** to get the exact run command, the working
directory to run from, and how the solution signals its answer in stdout
(e.g., banner format, last line, `Answer:` prefix). Do not ask the user
how to run the project — that information must be in CLAUDE.md. If it isn't,
inspect the build files and existing day code to infer it.

### Steps

1. **Read CLAUDE.md** — extract the run command template and output format.

2. **Read README.md** — parse the answer table for the requested day.
   The table looks like:
   ```markdown
   | Part | Answer |
   |-----:|-------:|
   |    1 |  12345 |
   |    2 |  67890 |
   ```
   Extract the expected answers for part 1 and part 2 (may be blank if not
   yet solved).

3. **Run part 1**, capture stdout. Look for the answer in the output —
   typically the last non-empty line, or a line matching `Answer: <value>`.

4. **Run part 2**, same approach.

5. **Report results** in a compact table:

   | Part | Expected | Got | ✓/✗ |
   |-----:|----------:|----:|-----|
   |    1 | 12345 | 12345 | ✓ |
   |    2 | 67890 | 67890 | ✓ |

6. If an expected answer is blank (not yet in README.md), report the output
   and ask whether to write it to README.md.

7. If the output doesn't match, show the full stdout to help debug.

### Flags

- `--example` / `-e`: run with `example.txt` instead of `input.txt`
- `--part <N>`: run only one part

---

## Common pitfalls to avoid

- **Read before asking.** For stub and run, CLAUDE.md is the source of truth
  for language, layout, run commands, and conventions. Read it first. Only
  ask the user when the project genuinely doesn't have the information.
- **Don't hardcode language assumptions.** Always derive the run command and
  layout from what's actually in the project (read existing files, check
  CLAUDE.md) rather than assuming.
- **Don't clobber existing work.** Before writing any file, check whether it
  exists. For CLAUDE.md, merge rather than overwrite. For README.md day
  sections, append rather than replace.
- **Don't invent answers.** When running, capture actual process output —
  don't guess or synthesize the answer.
- **Keep days independent.** Don't add shared state between days; the common
  library is the only cross-day code.

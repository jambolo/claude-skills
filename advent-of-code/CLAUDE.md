# CLAUDE.md — `advent-of-code` family

Guidance for the `advent-of-code` skill. See the repo root `CLAUDE.md` for skill anatomy and repo-wide conventions.

## The skill

`advent-of-code` is language-agnostic and multi-operation (init / scaffold / stub / run). Instruction-only (no templates). For existing projects it derives everything from the project's CLAUDE.md and files. Its scaffold operation is layered: repo bootstrap is **delegated to the matching `new-*-project` skill** via the Skill tool (inline fallback following the shared scaffolder conventions in `new-project/CLAUDE.md` for languages without one), then the AoC-specific layout is **researched from community practice** (well-starred repos, templates, dominant tooling) rather than hardcoded — the chosen structure and its sources are recorded in the generated project's CLAUDE.md.

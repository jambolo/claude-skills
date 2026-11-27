# 0011. C++ scaffolds ship a `.clang-format` so the CI format check has a stated style

**Status:** Accepted
**Date:** 2026-11-26
**Commits:** 5af7900

## Context

The C++ `lint-and-format` job has run `clang-format --dry-run --Werror` on pull requests since ba697a6, but the scaffold produced no style file. The skill documented the result as:

> `clang-format --dry-run --Werror` (LLVM fallback style unless the project adds a `.clang-format`)

So a new project was gated on a style nobody had chosen — clang-format's built-in LLVM fallback (2-space indent, 80 columns) — and it was enforced in CI with nothing in the repo for an editor or a developer's local `clang-format` to read. 5af7900 added a four-line template and a commit for it:

```yaml
BasedOnStyle: Google
ColumnLimit: 120
IndentWidth: 4
AccessModifierOffset: -4
```

> Also copy `templates/.clang-format` (Google style, 120 columns, 4-space indent) verbatim to `.clang-format` and commit it: `git add .clang-format && git commit -m "Added .clang-format"`.

and the CI description now reads "using the scaffolded `.clang-format`".

## Decision

`new-cpp-project` scaffolds a `.clang-format` — Google base style, 120-column limit, 4-space indent, access modifiers flush with the class — copied verbatim from `templates/.clang-format` and committed as its own step ("Added .clang-format") alongside the presets. The CI format check enforces that file rather than a tool default. Like every other artifact, an existing `.clang-format` is kept as-is in partial-setup mode ([0005](0005-idempotent-partial-setup-mode.md)).

## Rationale

- All projects should maintain a consistent style, so the scaffold gives every new C++ project the same one.
- The specification is a compromise between what the author likes and the most common style.

## Consequences

- The enforced style is visible and editable in the repo, and editors pick it up, so local formatting matches the CI gate.
- The seeded history gains a commit; shipped as a minor bump (`new-cpp-project` 2.1.0).
- The style is a short delta on a named base, not a full dump; a project changes it by editing four lines, at the cost of diverging from the other scaffolded projects.
- C++ now matches the scaffolders whose formatter config is part of the scaffold (Prettier in TypeScript and Tauri); there is still no `.clang-tidy`, so the lint half of the job runs clang-tidy's default checks.

## Alternatives considered

- **No style file; rely on the LLVM fallback** (ba697a6 through 7cb1c8f): the gate was real but the style was implicit, and nothing kept projects consistent with one another.

# 0003. Node-based scaffolds are pnpm-only and create their own directory

**Status:** Accepted
**Date:** 2026-06-10
**Commits:** e5badcf, ba697a6, c5577ac

## Context

646403b's `new-typescript-project` took a package-manager input and operated in place:

> - **package manager** — `npm` or `pnpm`. Ask if the user did not say. This selects every install command and the CI workflow template.
>
> Operates in the current working directory. `cd` into the intended (already created) project folder first and confirm it is correct.

backed by a command map (`npm init -y` / `pnpm init`, `npm install -D` / `pnpm add -D`, `ci-npm.yml` / `ci-pnpm.yml`). e5badcf ("Finished typescript-init-default", authored 2026-06-10, landed 2026-07-04) removed the input, the map, and both templates, renamed the skill "New TypeScript project (pnpm)", made the description trigger on "TypeScript, TS, or pnpm project", and switched to `mkdir <project name> && cd <project name>` like the other scaffolders. It also replaced `npx gitignore` / hand-written LICENSE with `pnpm dlx gitignore node` / `pnpm dlx license MIT`, and dropped the `version:` input of `pnpm/action-setup` in favor of the `packageManager` field `pnpm init` writes ("if both are present and disagree, the action fails with 'Multiple versions of pnpm specified'").

ba697a6 then wrote the choice into the family contract so it would not be read as an oversight:

> **pnpm is the preferred package manager for Node-based projects** — `new-typescript-project` is pnpm-only by design (not an omission), and any future Node-based scaffolder should default to pnpm too (`pnpm add`, `pnpm dlx` instead of `npx`). Plain `npx` remains fine for one-off generators in non-Node projects.

c5577ac's `new-tauri-project` followed it (`pnpm init`, `pnpm add`, `pnpm dlx`, `pnpm tauri icon`).

## Decision

Scaffolders for Node-based stacks use pnpm exclusively — `pnpm init`, `pnpm add`, `pnpm exec`, `pnpm dlx` for generators — and do not offer an npm/yarn choice. The pnpm version is declared once, in `package.json`'s `packageManager` field, and CI reads it from there (`pnpm/action-setup` with no `version:` input). Non-Node scaffolders keep using `npx` for one-off generators. Like every other scaffolder, the Node ones create and enter `<project name>` themselves rather than operating in the current directory.

## Consequences

- One CI template per Node scaffold instead of one per package manager; lockfile is always `pnpm-lock.yaml` (`--frozen-lockfile` in CI).
- A user who wants npm gets a pnpm project; the description no longer says "optionally specifying npm or pnpm".
- The `advent-of-code` skill's scaffold table still carries the pre-e5badcf note for TypeScript ("Operates in the current directory — `mkdir` the project folder and `cd` in first. Pass through the user's npm/pnpm choice"); it is stale relative to this decision and needs correcting when that table is next touched.
- Future Node-based scaffolders inherit the rule from the family `CLAUDE.md` without a per-skill justification.

## Alternatives considered

- **User-selected npm or pnpm with parallel templates** (646403b) — removed in e5badcf; the two-template, command-map design doubled the surface to keep fresh for no difference in the produced project.
- **Scaffolding in the current directory** (646403b, TypeScript only) — removed in e5badcf so that every scaffolder owns directory creation; ba697a6 later made that `mkdir -p` for the partial-setup case ([0005](0005-idempotent-partial-setup-mode.md)).

# 0006. Local workflow validation with act is optional, scoped to runnable jobs, and reported

**Status:** Accepted
**Date:** 2026-07-09
**Commits:** ed4d9ac, ba697a6, c5577ac

## Context

ed4d9ac made act verification a hard requirement of the Rust scaffold — "Requires `act` on PATH and Docker Desktop running (`docker info` must succeed)" — with a three-step protocol (`act -l`, `act push`, `act pull_request`) whose purpose is to prove the PR gate: "Confirm step 2 skips lint/format and step 3 includes them; that proves the pull-request gating works." It already acknowledged the limits: act runs Linux containers only, so the `windows-latest` leg, the Pages `docs` job, and the Codecov `coverage` job cannot execute.

ba697a6 downgraded the requirement to optional and standardized the check and the reporting across all skills:

> ```bash
> command -v act && docker info >/dev/null 2>&1
> ```
>
> If `act` is not on PATH or Docker is not running, **skip this whole section** — it is optional validation, not a failure; state in the final report that act verification was skipped and why.

and the family contract: "act validation is optional: skipped (and reported as skipped) when `act` is not on PATH or Docker isn't running." The same commit gave C++ the opposite instruction, because its matrix cannot be reduced to what act can run:

> Do not verify this workflow with `act` — act does not support the `windows-latest` runner, so it cannot exercise the build matrix's Windows leg. Keep **both** matrix legs (`ubuntu-latest` and `windows-latest`) and let GitHub-hosted runners validate the workflow.

c5577ac added the cost dimension for Tauri: both runnable jobs install webkit2gtk and compile the full dependency tree in the container, "so the first run takes many minutes — treat a timeout as 'skipped', not a failure."

## Decision

A scaffolder attempts act verification only when `act` is on PATH and Docker is running; otherwise it skips the section and says so in its final report. When it runs, it scopes act to the jobs that can execute in a Linux container (`act push -j build-and-test`, `act pull_request -j lint-and-format`) and treats the `windows-latest`/`macos-latest` legs, `docs`, `coverage`, and a Tauri timeout as expected non-results. A skill whose workflow cannot be meaningfully exercised under act (C++) opts out entirely and relies on GitHub-hosted runners.

## Consequences

- A scaffold never fails because of missing validation tooling; the trade is that a template regression can reach the repo and surface only on the first push.
- The final report of every scaffolder has a fixed shape: created path, kind where applicable, skipped partial-setup steps, act results or the reason they were skipped.
- The act protocol is written per skill (job names and caveats vary), so a template job rename must be mirrored in the "Verify the workflow with act" section.
- `advent-of-code` inherits the behavior through delegation and does not re-validate.

## Alternatives considered

- **Mandatory act run** (ed4d9ac, 646403b) — replaced in ba697a6; it made `act` and Docker hard prerequisites of scaffolding even though they validate only a subset of the workflow.

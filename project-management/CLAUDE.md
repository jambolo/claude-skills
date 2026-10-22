# CLAUDE.md — `project-management` family

Guidance for the `lead-developer` and `pipeline-tools` skills and the `planner`, `decomposer`, `supervisor`, `worker`, and `worker-lite` agents. See the repo root `CLAUDE.md` for skill/agent anatomy and repo-wide conventions.

## Skill vs. agent

`lead-developer` is a skill (`SKILL.md`): its plan operation interviews the user, which a subagent cannot do, and its execute operation runs inline at depth 0 so the chain below it fits the harness's default subagent nesting limit. `pipeline-tools` is a skill because a skill leaf can carry `scripts/` and a fixture and installs at a path the agents can name (`~/.claude/skills/pipeline-tools/scripts/`); it has no real operation of its own beyond the smoke test. The five pipeline stages are **agent definitions** (`AGENT.md`, installed as `~/.claude/agents/<name>.md`): they never need the user mid-run, and the agent frontmatter gives what a skill cannot — pinned `model:`/`effort:` per stage, a `tools:` allowlist (planner, decomposer, and the workers have no `Agent` tool), `maxTurns:` on the workers, and `omitClaudeMd:` on the workers (Claude Code 2.1.271+), so they see their step file and nothing else — not even the project's CLAUDE.md.

| Leaf | Kind | Spawns |
| --- | --- | --- |
| `lead-developer` | skill | planner, decomposer, supervisor |
| `pipeline-tools` | skill | nothing (scripts the agents call) |
| `planner` | agent | nothing |
| `decomposer` | agent | nothing (returns `needs-amendment`; the caller spawns the planner) |
| `supervisor` | agent | worker / worker-lite, decomposer (revision), planner (amendment) |
| `worker`, `worker-lite` | agent | nothing (no `Agent` tool) |

Callers spawn a stage with `subagent_type: <name>` and `run_in_background: false` (omitted only when the Agent tool does not list it — an unlisted parameter fails the call), and pass **no** `model`, `effort`, or `isolation` option. Every agent ends with `RESULT: done | needs-human | needs-amendment | failed`; a nested `needs-human` is forwarded verbatim up the chain until `lead-developer` (or the person who @-mentioned the agent) relays it to the user.

## The pipeline

The deterministic mechanics are the `pipeline-tools` scripts: `wave-create.sh` (worktrees at BASE with the dependency gate), `step-verify.sh` (one commit, scope, acceptance), `step-merge.sh` (merge, ledger row, commit, cleanup), `dod-run.sh` (a `dod` block), `find-formatter-gates.sh`. The agents call them by path and act on their verdict lines. The step schema (`files_in_scope`, `acceptance_cmd`, `acceptance_expect` and their indentation), the ledger Steps columns, and the `dod` block format are parsed by those scripts — change the schema and the scripts together, and run `bash project-management/pipeline-tools/scripts/selftest.sh`.

`worker` carries the per-step contract (path discipline, base assertion, honest acceptance, report format, one-commit rule) in its own definition and reads its step file itself, so the supervisor hands it a five-line packet. `worker-lite` is the same contract on Haiku: its body must stay byte-identical to `worker`'s (the drift check enforces it); only the frontmatter differs.

The three pipeline agents install independently and cooperate only through the shared Markdown artifacts keyed by `<plan-name>` — the **"Shared model" section is duplicated verbatim across all three AGENT.md files and must be kept in sync** when edited (bump all three). The duplicated span runs from the section heading to the `<!-- shared-model: end -->` marker; text after the marker is stage-specific. `bash project-management/scripts/check-shared-model.sh` exits 1 when the three copies differ, or when the worker and worker-lite bodies differ — run it before committing any edit to those agents. The workers do not carry the Shared model; their contract must stay consistent with the "Worker report & commit protocol" paragraph inside it.

## The lead-developer stage

`lead-developer` does not carry the pipeline's "Shared model" section and its edits do not require bumping the agents; any pipeline escalation an agent cannot resolve stops the run for human intervention.

## Editing an agent

- `description` is an auto-delegation trigger: keep the "invoke ONLY for pipeline work" exclusions, or the agent gets spawned on unrelated prompts.
- Changing `model`, `effort`, `tools`, `maxTurns`, or `omitClaudeMd` is a minor bump; changing the packet/prompt contract, the `RESULT:` protocol, or an artifact's format (ledger columns, step fields, report fields) is major.
- The harness limits the agents rely on are documented defaults, not constants: subagent nesting depth (3 below the main conversation; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`), concurrency (20; `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`), and the base of `isolation: worktree` (the remote default branch unless `worktree.baseRef` is `head`). Re-check them against the Claude Code docs after an upgrade; whether foreground Agent calls issued in one message run concurrently is not documented, but the 2026-10-22 smoke run showed they do (parallel steps' commits landed one second apart).
- Agents can't ask the user — any new decision point must return `needs-human`, never assume.
- Installed definitions are read at session start; test in a fresh session after copying to `~/.claude/agents/`.
- End to end: `bash project-management/pipeline-tools/scripts/make-fixture.sh <empty dir>` builds the smoke-test repository (two phases, four pre-written steps); supervise its two phases in a session opened there and check the ledger, worktrees, and branches as `pipeline-tools/SKILL.md` describes. Run it after a Claude Code upgrade and after any change to the supervisor or workers.
- Model and effort pins change only on benchmark evidence: `bench-run.sh` (headless, per-run frontmatter overrides in the fixture's `.claude/agents/`, results in a TSV) and `bench-summary.sh`, with the decision rule in `pipeline-tools/SKILL.md`. A passing configuration is applied as a minor bump; the result rows and the decision record go in `project-management/benchmarks/<date>-bench-results.tsv` and `<date>.md`, and the commit message cites them. The pins also appear as text in the three Shared model copies, the lead-developer model table, and the README — update all of them together.

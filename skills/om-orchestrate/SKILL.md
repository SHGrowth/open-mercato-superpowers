---
name: om-orchestrate
description: Fully autonomous parallel agent fleet that ships OM apps end-to-end via GitHub Issues + PRs. Subcommands — `init`, `run`, `status`, `stop`. Triggers — "orchestrate", "oneshot", "ship the app", "run all specs", "autonomous fleet".
---

# om-orchestrate

Coordinates a fleet of autonomous agents that take an App Spec from decomposition through merged PRs. The system uses **GitHub Issues + labels + PR comments** as the only coordination substrate — no filesystem queue, no cmux ceremony, no IPC daemon.

**Phase 1 (v1.12.0) scope:** singleton mode — one coding agent + one e2e singleton + auto-merge. Validates the protocol on a single spec at a time. Multi-agent parallelism arrives in Phase 2 (v1.13.0); full failure recovery + Projects v2 view in Phase 3 (v1.14.0).

## Subcommands

| Command | What it does |
|---|---|
| `/om-orchestrate init` | Bootstrap the current repo: write `.ai/orchestration.yml`, create the 11 status labels, verify `gh auth`. See `references/bootstrap.md`. |
| `/om-orchestrate run [<app-spec-path>]` | Start the dispatcher. Spawn the e2e singleton + one coding agent. Run until the queue drains. See `references/dispatcher.md`. |
| `/om-orchestrate status` | Read-only report: issues by label, agents alive, ETA. No mutations. |
| `/om-orchestrate stop` | Graceful shutdown: refuse new claims, let in-flight agents finish their tick, kill long-lived e2e process when no work remains. |

If the user invokes `/om-orchestrate` with no subcommand, route to `init` if `.ai/orchestration.yml` is missing, otherwise to `run`.

## When to load which reference

Detail lives in references; only load what you need. Never load all at once.

| Task | Load |
|------|------|
| `init` subcommand workflow | `references/bootstrap.md` |
| `run` subcommand — dispatcher script + invariants | `references/dispatcher.md` |
| Understanding the agent contracts (coding, e2e, merge) | `references/agent-contracts.md` |
| Claim protocol (race-safe issue claims) | `references/claim-protocol.md` |
| Failure recovery rules (Phase 3 territory; reference exists from day 1 for documentation completeness) | `references/failure-recovery.md` |
| `.ai/orchestration.yml` schema | `references/orchestration-yml.md` |

The agent prompts (`prompts/coding-agent.md`, `prompts/e2e-agent.md`, `prompts/merge-agent.md`) are not loaded by this skill — they are read by the dispatcher script at runtime and fed to background `claude -p` processes.

## Pre-flight

1. **Verify `.ai/orchestration.yml` exists** unless the subcommand is `init`. If missing, abort with: *"This repo is not configured for orchestration. Run `/om-orchestrate init` first."*
2. **Verify `gh auth status`** returns a logged-in user. If not, abort with the install command.
3. **Verify the 11 status labels exist** in the repo (`status:backlog`, `status:ready`, `status:coding`, `status:needs-e2e`, `status:e2e-running`, `status:e2e-passed`, `status:e2e-failed`, `status:review`, `status:review-clean`, `status:blocked`, `human-review`). If any missing, abort with: *"Labels missing. Run `/om-orchestrate init` to recreate."*

## Communication style

All GitHub surfaces (issue titles/bodies, PR titles/bodies, comments) MUST default to simple non-technical language. Tech detail belongs in the repo (run plans, spec files, commit messages). When tech IS needed (specific bug, security finding), keep it short and lean. Never paste secrets, env vars, or full test output into PR comments.

See the design spec (`docs/specs/2026-05-07-github-tasks-orchestration.md`) § Communication style for the full rule.

## Rules

- MUST NOT add new top-level skills as part of orchestration features. The agent prompts (`prompts/*.md`) are NOT skills — they are content fed to background `claude -p` processes by the dispatcher. This skill is the only orchestration entry point.
- MUST read `.ai/orchestration.yml` before any spawning. Project-specific commands and env vars come from there, not from hardcoded assumptions.
- MUST verify `gh auth status` before any subcommand that touches GitHub.
- MUST treat the `human-review` label as a hard veto on any issue. Do not advance issues bearing it.
- MUST log to `/tmp/om-agent-*.log` so the user can `tail -f` for visibility. The user does not see in-process agent output otherwise.
- MUST NOT run `om-implement-spec` inline as a subcommand. Spawn the coding agent prompt instead — that prompt internally invokes `om-implement-spec` per its own logic.
- MUST exit cleanly (kill the e2e long-lived process, write a final summary) when the orchestration completes (queue drained) OR when `stop` is invoked.

## Cross-link

- `docs/specs/2026-05-07-github-tasks-orchestration.md` — design spec v0.3 (full protocol, state machine, recovery rules, phasing).
- v1.11.5 — fixed agent sleeping anti-pattern; this skill provides the peer to yield to.
- v1.11.6 — fixed post-PR review skip; this skill integrates review as a labeled state in the fleet.

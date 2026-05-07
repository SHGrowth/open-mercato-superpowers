# GitHub-Tasks Orchestration — fully autonomous parallel agent fleet

**Date:** 2026-05-07
**Status:** Design v0.3 — adds context-budget discipline + compressed phasing toward v1.14.0 oneshot goal
**Owner:** Mat (CEO)
**Driven by:** v1.11.5 forensic (sleeping anti-pattern); v1.11.6 forensic (post-PR review gap); user goal — oneshot OM systems from App Spec; user directive — keep agent context lean
**Prior revisions:**
- v0.1 @ commit `2609c8e` — initial draft, superseded
- v0.2 @ commit `7ba79a7` — addressed Piotr's pre-impl analysis blockers (C1-C4, I3) + added oneshot extensions (auto-merge, failure recovery, multi-PR conflict). Superseded by this revision.
- v0.3 (this) — adds context-budget discipline (≤1 new top-level skill), compresses phasing toward v1.14.0 as the actual goal, retires v1.11.7-as-its-own-release.

## TL;DR

om-superpowers becomes a fleet of agents coordinated entirely through **GitHub Issues + labels + PR comments**. No filesystem queue, no cmux ceremony, no IPC daemon. The user runs one command (`/om-orchestrate <app-spec>`); the system bootstraps the project (creates labels, writes per-project config), spawns N coding agents + 1 e2e singleton, and runs autonomously through merge. End state: typing `/om-orchestrate <app-spec>` produces a fully merged OM app with no babysitting.

## Why this design

Three failure modes from prior PRM forensics drove this:

1. **v1.11.5 — `/loop` self-pace burns wall-time on idle ticks.** Root cause: agents waiting on something (long e2e runs) but no way to *yield* their context to a different worker. They slept instead of yielding.
2. **v1.11.6 — `om-implement-spec` ships PRs without real review.** Root cause: the implementer's "done" was tied to its own checklist, not to a downstream gate enforced by another agent.
3. **PRM serial implementation is slow.** 7 specs × ~2.5h sequential each ≈ 14h wall-time. Three of those specs are independent post-MVP. Most of that time is one agent waiting for tests/CI while another agent could be coding.

All three are symptoms of one shape: **one agent doing everything, blocking on its own gates, with no peer to hand work to.** Tasks-on-GitHub turns this into a fleet with explicit hand-offs.

The user's stated goal — *oneshot OM systems* — adds three additional requirements not present in the prior failures:

4. **Auto-merge** when a PR is review-clean (currently humans merge; oneshot can't).
5. **Failure recovery** when an agent crashes mid-spec (currently a human re-dispatches).
6. **Multi-PR conflict resolution** when parallel agents touch shared files (does not exist today; needed once parallelism is real).

Plus a fourth design constraint surfaced 2026-05-07:

7. **Context budget — every skill loads at session start, taxing every future agent in the project.** v0.1 implied 5+ new top-level skills (`om-orchestrate`, `om-e2e-runner`, `om-pr-tick`, `om-merge-agent`, etc.). At ~120-200 tokens of frontmatter each, that's a 1k+ token tax on every session forever. Not acceptable. v0.3 commits to **at most one new top-level skill** for the entire orchestration system; everything else is prompts (dispatcher-fed, never in the router) or references (on-demand, not at session start).

These are addressed below in dedicated sections.

## Why GitHub Tasks (Issues), not just PRs

Earlier draft used PRs as work units. Issues are a strict upgrade because:

| | PR-as-work-unit | Issue-as-work-unit |
|---|---|---|
| When does the work exist? | Only after `gh pr create` | From decomposition — before any code |
| What is "done"? | PR merged | Issue closed (PR is one deliverable artifact) |
| Failed PR? | Reopen the PR (awkward, history confusing) | Issue stays open; new PR linked; clean history |
| Dependencies | `Depends on: #PR` in body, manually parsed | `Blocked by #<issue>` — well-known GitHub idiom |
| Visibility | `gh pr list` | Project board (kanban) when v2 lands |
| Decomposition phase | No artifact until first agent opens a PR | One issue per spec the moment om-cto decomposes — visible day 1 |

## Why fully autonomous (om-cto creates issues itself)

Decided 2026-05-07. Tradeoff:

- **Agent-created (chosen)**: om-cto, on App Spec decomposition, opens one issue per spec and links the spec file in the body. The fleet picks them up. Humans veto via the `human-review` label, which pauses any task it's applied to.
- **User-staged (rejected)**: requires manual issue creation per spec; loses the autonomous loop; reduces to a fancy task tracker.

Veto channel preserved via `human-review` label. Apply it to any issue and the fleet skips that issue until the label is removed. No code changes needed to halt — just label.

## Project-agnostic configuration — `.ai/orchestration.yml`

**(Addresses analysis C4 — community-fitness blocker.)** Every adopting OM project declares its specifics in `.ai/orchestration.yml` at the repo root:

```yaml
# .ai/orchestration.yml
schema_version: 1

e2e:
  command: "yarn test:integration:ephemeral"
  required_env:
    - OM_PRM_WIC_IMPORT_SECRET   # project-specific; can be empty
  timeout_minutes: 15
  artifact_paths:
    - "test-results/"            # what to attach if tests fail

paths:
  run_plans: ".ai/runs"
  specs: ".ai/specs"
  app_spec: "app-spec/app-spec.md"

labels:
  prefix: "status:"              # e.g. status:coding; some projects may want orch:coding
  human_veto: "human-review"

merge:
  strategy: "squash"             # squash | merge | rebase
  delete_branch: true
  base_branch: "develop"         # or "main" for some projects
  required_checks: []            # gh check names that MUST be green before auto-merge

orchestration:
  parallel_n: 5                  # default coding agents in flight
  poll_cadence_seconds: 60       # coding agent /loop tick
  e2e_poll_cadence_seconds: 30
  idle_exit_ticks: 5             # exit after N consecutive empty polls
```

The e2e singleton, coding agents, and dispatcher all read this file on boot. Without it, agents refuse to start with a clear message pointing at `om-orchestrate init`. Project-specific assumptions live here, not in the skills.

## Bootstrap — `om-orchestrate init`

**(Addresses analysis N3.)** A new sub-skill that prepares any OM repo to host the orchestration fleet. Steps:

1. Detect project shape (read `package.json` test scripts, scan for existing `.ai/` directories, look for an App Spec).
2. Generate stub `.ai/orchestration.yml` from a template, populated with detected commands. User reviews and edits.
3. Create the 11 status labels in the repo via `gh label create` (idempotent — skips if they exist).
4. Verify `gh auth status` and the required scopes (`repo`, `read:project` if Projects v2 is in use).
5. Verify required env vars from the config file are present in the user's shell (warn, don't block).
6. Print a short summary: "Repo ready. Run `/om-orchestrate <app-spec-path>` to start."

`om-orchestrate init` is idempotent — running it twice does not re-create labels, does not overwrite the config. It surfaces any drift.

## State machine — label vocabulary

Single-axis status field, encoded as labels until Projects v2 migration. Label prefix configurable via `.ai/orchestration.yml`'s `labels.prefix`.

| Label | Meaning | Set by | Cleared by |
|---|---|---|---|
| `status:backlog` | Issue exists, not yet ready (deps unmet) | om-cto on creation | dispatcher when deps met |
| `status:ready` | Ready for a coding agent to claim | dispatcher | claiming agent |
| `status:coding` | A coding agent is actively working | claiming agent | the same agent on yield |
| `status:needs-e2e` | Coding agent yielded; e2e queue should pick up | coding agent | e2e agent on claim |
| `status:e2e-running` | E2E singleton is processing | e2e agent | e2e agent on result post |
| `status:e2e-passed` | Tests green; coding agent should resume to code-review | e2e agent | resuming coding agent |
| `status:e2e-failed` | Tests red; coding agent should resume to fix | e2e agent | resuming coding agent |
| `status:review` | Code-review pass running (`om-auto-review-pr`) | coding agent post-e2e-pass | review agent |
| `status:review-clean` | Review clean; ready for auto-merge | review agent | merge step |
| `status:blocked` | Real blocker, needs human | any agent on irrecoverable error | human |
| `human-review` | Pause; do not advance until removed | human | human |

## Claim protocol — corrected

**(Addresses analysis C1 — the critical race bug in v0.1.)** The v0.1 spec claimed `gh issue edit --add-assignee` returns 422 on a second add. It does not — assignees are additive. The corrected primitive uses **a single-instance label** as the lock, with verify-after-add:

```bash
# Coding agent claims issue 42
ME="agent-$(date +%s%N)-$$"   # unique per process; timestamp-pid

# 1. Remove any prior claim labels (single-instance pattern)
gh issue edit 42 --remove-label "$(gh issue view 42 --json labels --jq '.labels[].name | select(startswith("claim:"))')" 2>/dev/null || true

# 2. Add our claim label
gh issue edit 42 --add-label "claim:$ME"

# 3. Verify-after-add — re-fetch and check we're the lowest-timestamp claim
WINNER=$(gh issue view 42 --json labels --jq '.labels[].name | select(startswith("claim:")) | sub("claim:";"")' | sort | head -1)

if [[ "$WINNER" != "$ME" ]]; then
  # Another agent's claim is older — yield
  gh issue edit 42 --remove-label "claim:$ME"
  exit 0
fi

# 4. We won — convert to status:coding and add assignee
gh issue edit 42 --remove-label "status:ready" --add-label "status:coding"
gh issue edit 42 --add-assignee @me
```

Why this works:
- Step 1 + 2 are atomic per-call (GitHub label edits are atomic).
- Step 3 is the deterministic tiebreaker: lowest unix-timestamp wins.
- Steps 1-3 racing across N agents: all N add their claim labels. All N read all N labels. All N agree on the same winner. N-1 self-evict.
- The window between steps 2 and 3 is ~200ms; race resolution is sub-second.

**Stale-claim recovery:** if `claim:<ME>` is older than 30 minutes and the current agent verifies it owns no `status:coding` label on that issue (i.e., it crashed before step 4), any subsequent claimant treats it as expired and removes it.

## Lock protocol reconciliation — issue-level vs PR-level

**(Addresses analysis I3.)** Existing `om-auto-create-pr` / `om-auto-continue-pr` / `om-auto-review-pr` use a single `in-progress` label on **PRs** as their lock. The new orchestration uses `status:coding` (and the family) on **issues**. Both coexist:

| Layer | Label | Owner | Scope |
|---|---|---|---|
| Issue | `status:coding` (etc.) | Orchestration agents | "This issue is in active development" |
| PR | `in-progress` | Auto-* trio | "Two auto-skills must not clobber this PR mid-flight" |

The two locks are *complementary*, not redundant:

- A coding agent owns issue #42 (`status:coding`). It invokes `om-auto-create-pr` to start the PR. Auto-create-pr's own claim adds `in-progress` on the PR. Both labels are correct: the issue is coding-active AND the PR is auto-skill-active.
- When the coding agent yields to e2e, it removes `status:coding` from the issue → adds `status:needs-e2e`. Auto-create-pr's `in-progress` on the PR is also released by auto-create-pr's normal trap/finally.
- When the e2e agent runs tests, it does NOT touch the PR's `in-progress` label — that's the auto-* trio's namespace.
- When the orchestration's auto-merge step runs (see below), it owns the merge action and applies `in-progress` to the PR for the duration to prevent any other auto-* from clobbering.

Rule: **orchestration agents touch only `status:*` labels on issues. Auto-* trio touches only `in-progress` on PRs. Crossover is never required.**

## Skill surface budget — minimize context tax

**Hard rule: the entire orchestration system adds at most ONE new top-level skill to the om-superpowers plugin.**

Why this matters: every skill registered in `.claude-plugin/plugin.json` loads its frontmatter description at session start in any project that has om-superpowers installed. The current 24 plugin skills cost ~2.5k tokens of permanent context tax per session. Naive design (`om-orchestrate`, `om-orchestrate-init`, `om-e2e-runner`, `om-pr-tick`, `om-e2e-tick`, `om-merge-agent` as separate skills) would add ~1k tokens to every session, forever — even sessions that never invoke orchestration.

**Three tiers of code in this design, with strict rules per tier:**

| Tier | What | Loads at session start? | Example |
|---|---|---|---|
| **Top-level skill** | User-invocable `/om-<name>` entry points | YES — frontmatter description + name | `om-orchestrate` (the only new one) |
| **References** | On-demand documentation loaded by a parent skill | NO — only loaded when parent reads them | `skills/om-orchestrate/references/agent-contracts.md`, `references/dispatcher.md`, `references/recovery.md` |
| **Prompts** | Templates fed by the dispatcher to background `claude -p` processes | NO — not registered as skills, the dispatcher reads them at runtime | `skills/om-orchestrate/prompts/coding-agent.md`, `prompts/e2e-agent.md`, `prompts/merge-agent.md` |

**The single new skill, `om-orchestrate`, has subcommands**:

| Subcommand | What it does |
|---|---|
| `/om-orchestrate init` | Bootstrap UX — create `.ai/orchestration.yml`, create labels, verify gh auth |
| `/om-orchestrate run [<app-spec>]` | Start the dispatcher; spawn fleet; run until queue drains |
| `/om-orchestrate status` | Read-only status report (issues by label, agent processes alive, ETA) |
| `/om-orchestrate stop` | Graceful shutdown — let in-flight agents finish, refuse new claims |

The skill's `SKILL.md` is **minimal** — frontmatter + 1-2 paragraphs of router context. Detailed workflow lives in `references/<topic>.md` files loaded on-demand:

```
skills/om-orchestrate/
├── SKILL.md                                # ~80 lines, just enough for routing
├── references/
│   ├── agent-contracts.md                  # coding agent / e2e / merge contracts
│   ├── claim-protocol.md                   # the corrected claim primitive
│   ├── dispatcher.md                       # the bash dispatcher script + invariants
│   ├── failure-recovery.md                 # crash recovery rules
│   ├── orchestration-yml.md                # config schema reference
│   └── bootstrap.md                        # init subcommand details
├── prompts/
│   ├── coding-agent.md                     # fed to claude -p by dispatcher
│   ├── e2e-agent.md
│   └── merge-agent.md
└── scripts/
    └── dispatcher.sh                       # the actual bash wrapper
```

**Patches to existing skills also obey the budget**: the v1.12.0 patch to `om-implement-spec` adds ~5 lines to its existing Step 8, not a new skill or new section. The v1.13.0 patch to `om-cto` adds ~5 lines to its existing dispatch-context, not a new skill.

**Net session-start context cost** for the entire orchestration system: ~150 tokens (one new skill description). v0.1's implied design would have cost ~1000 tokens. 6× reduction.

## Agent contracts

The contracts below describe agent **behavior**, not skill **registration**. Only `om-orchestrate` is a registered skill; the coding/e2e/merge agents are background `claude -p` processes fed by the dispatcher with prompts from `skills/om-orchestrate/prompts/`.

### `om-orchestrate` — the one user-invocable skill

Invoked by user as `/om-orchestrate <subcommand>`. Reads `.ai/orchestration.yml` for project specifics, `app-spec/app-spec.md` for the input. The subcommand routes to the appropriate workflow:

1. Verify `om-orchestrate init` has been run (config exists, labels exist). If not, abort with pointer.
2. For each spec in the App Spec / EXECUTION-PLAN that lacks a corresponding open issue, create one:
   - Title, body, `Blocked by` lines, initial label (`status:backlog` or `status:ready`).
3. Spawn the fleet via the **outer dispatcher** (Pattern A — see "Spawning" below):

```bash
#!/bin/bash
# om-orchestrate dispatcher (simplified)
set -euo pipefail
source .ai/orchestration.yml-export   # converts YAML to env
N="${OM_PARALLEL_N:-5}"
EXIT_TICKS="${IDLE_EXIT_TICKS:-5}"
idle=0

# Spawn singleton e2e agent (one process running its own /loop)
nohup claude -p "/loop ${E2E_POLL_CADENCE_SECONDS}s /om-e2e-tick" \
  --dangerously-skip-permissions \
  > "/tmp/om-agent-e2e.log" 2>&1 &
E2E_PID=$!

# Outer loop — keeps N coding agents in flight until queue drains
while true; do
  in_flight=$(gh issue list --label "status:coding" --json number --jq 'length')
  ready=$(gh issue list --label "status:ready" --json number --jq 'length')
  needs_resume=$(gh issue list --label "status:e2e-passed,status:e2e-failed" --json number --jq 'length')
  total_open=$(gh issue list --label "status:backlog,status:ready,status:coding,status:needs-e2e,status:e2e-running,status:e2e-passed,status:e2e-failed,status:review" --state open --json number --jq 'length')

  if [[ "$total_open" -eq 0 ]]; then
    idle=$((idle+1))
    if [[ "$idle" -ge "$EXIT_TICKS" ]]; then
      kill "$E2E_PID" 2>/dev/null || true
      echo "Queue drained. Exiting."
      exit 0
    fi
  else
    idle=0
  fi

  # Spawn coding agents up to N — each is a single-tick fresh process
  agents_to_spawn=$((N - in_flight))
  if [[ "$agents_to_spawn" -gt 0 && $((ready + needs_resume)) -gt 0 ]]; then
    for i in $(seq 1 "$agents_to_spawn"); do
      nohup claude -p "/om-pr-tick" --dangerously-skip-permissions \
        > "/tmp/om-agent-coding-$(date +%s)-$i.log" 2>&1 &
    done
  fi

  sleep "${POLL_CADENCE_SECONDS:-60}"
done
```

The dispatcher is short, transparent, and terminates when the queue drains. The e2e agent runs in its own long-lived process (exits when no work for `$IDLE_EXIT_TICKS` ticks). Coding agents are per-tick fresh `claude -p` spawns — they exit naturally on session end; the dispatcher decides whether to spawn more.

### Coding agent — `prompts/coding-agent.md` (background process, not a skill)

The dispatcher script reads this prompt and feeds it to a fresh `claude -p` process per tick. The agent runs **one tick** per process invocation, picks up an issue or resumes prior work, then exits. **Not registered as `/om-pr-tick` or any other slash command** — the only entry point is the dispatcher.

Steps:

1. **Find work**:
   - If I have a previous unresolved claim (`claim:agent-*` label still on an open issue, my hostname/PID embedded), resume that issue.
   - Otherwise: `gh issue list --label status:ready,status:e2e-passed,status:e2e-failed --no-deps --jq 'first'`.
   - "no-deps" = no `Blocked by #<open-issue>` references.
   - If no candidate, exit (dispatcher decides whether to respawn).

2. **Claim** (per "Claim protocol — corrected" above). On race-loss, exit; dispatcher tries another tick.

3. **Work**:
   - If `status:ready` (fresh): invoke `om-implement-spec` or `om-auto-create-pr` per the spec linked in the issue body. Open PR with `Closes #<issue>` in body.
   - If `status:e2e-passed`: invoke `om-auto-review-pr <PR#>` (per v1.11.6). On clean → set `status:review-clean`. On findings → autofix loop, eventually re-queue for e2e.
   - If `status:e2e-failed`: read the e2e agent's PR comment with results. Fix the failures. Re-stage, push, re-queue for e2e.

4. **Yield to e2e** (when ready for tests):
   - Stage commits, push branch.
   - `gh issue edit <#> --remove-label status:coding --add-label status:needs-e2e`.
   - Post lean handoff comment.
   - Exit.

5. **Exit conditions** (any of):
   - Yielded successfully (handoff complete).
   - No claimable work this tick.
   - Race-lost on claim attempt.
   - Irrecoverable error → set `status:blocked` + post error comment + exit.

### E2E singleton — `prompts/e2e-agent.md` (background process, not a skill)

The dispatcher spawns one long-lived `claude -p` process fed this prompt with a `/loop ${E2E_POLL_CADENCE_SECONDS}s` directive. **Not registered as `/om-e2e-tick`**. Runs as long as work exists or might arrive. Each tick:

1. **Singleton lock check**: read all open issues with `status:e2e-running`. If any have a "running" timestamp (from the labeling agent's comment) older than `e2e.timeout_minutes + 5`, reset to `status:needs-e2e` (stale recovery). If a non-stale running label exists owned by a different process, exit this tick (we're a duplicate; dispatcher should not have spawned us).

2. **Find next job**: `gh issue list --label status:needs-e2e --jq 'first'`. None → idle counter++; if idle counter ≥ `idle_exit_ticks`, run `/loop stop` and exit. Otherwise sleep until next tick.

3. **Claim**: `gh issue edit <#> --remove-label status:needs-e2e --add-label status:e2e-running`. Post a "Starting tests" comment.

4. **Run**:
   - `git worktree add` for the linked PR's branch.
   - Read `.ai/orchestration.yml`'s `e2e.command`, `e2e.required_env`, `e2e.timeout_minutes`.
   - Verify required env present; if missing, set `status:blocked`, post lean error, exit job.
   - Run the command, capturing stdout/stderr to `/tmp/om-e2e-<#>.log`.
   - Apply timeout — kill the process if it exceeds `e2e.timeout_minutes`.

5. **Post results** (lean style — see Communication style):
   - On pass: `gh pr comment <PR#> --body "Tests passed."` then `--add-label status:e2e-passed --remove-label status:e2e-running`.
   - On fail: `gh pr comment <PR#> --body "Tests failed: <one-line summary>. See test output in CI artifacts or worktree log."` then `--add-label status:e2e-failed`.
   - On timeout: `--body "Tests exceeded $TIMEOUT_MINUTES min. Killed."` then `--add-label status:e2e-failed`.
   - **Never paste env vars or test output that may contain secrets.** See "Communication style — secrets" below.

6. **Cleanup**: `git worktree remove`. Remove the "Starting tests" comment (or edit it to "Done"). Continue to next tick.

### Review agent — uses existing `om-auto-review-pr`

When a coding agent's tick sees `status:e2e-passed` on its claimed issue, it transitions to `status:review` and invokes `om-auto-review-pr <PR#>` (which itself runs `om-ds-guardian REVIEW`). On clean verdict → label `status:review-clean`. On findings → coding agent stays on the issue, applies autofix, re-queues for e2e.

This step uses v1.11.6's mandate — no separate review agent process needed; the coding agent invokes the review skill at the right state.

### Auto-merge — `prompts/merge-agent.md` (background process or coding-agent extension)

**(Addresses oneshot requirement #4.)** Implementation choice within the context budget: the merge logic ships as part of the coding agent's tick (when it sees `status:review-clean` on an issue it can claim, it runs the merge inline). Avoids spawning yet another agent type. The dedicated `prompts/merge-agent.md` is a content fragment included by `prompts/coding-agent.md` rather than a separate process — same context budget, cleaner separation in the prompt source.

When an issue reaches `status:review-clean`, the next coding agent tick performs the merge:

1. Read the linked PR. Verify all `merge.required_checks` (from `.ai/orchestration.yml`) are green via `gh pr checks <PR#>`. If not all green: re-queue for e2e (or set `status:blocked` if the failure is non-test).
2. Apply `in-progress` label on the PR (auto-* trio's lock — claims the merge action).
3. `gh pr merge <PR#> --${merge.strategy} --delete-branch=${merge.delete_branch}`.
4. On success: close the issue, post short comment "Merged. Spec done." Remove `in-progress`.
5. On failure (mergeable=false, conflict): set `status:blocked` on the issue, post the conflict info as a comment, leave the PR open. Conflict resolution path → see "Multi-PR conflict resolution" below.

The merge step does NOT touch `status:*` labels on the issue beyond closing it — the issue closing IS the terminal state. Auto-merge respects `human-review` label: if applied to an issue with `status:review-clean`, merge is paused.

## Failure recovery — NEW

**(Addresses oneshot requirement #5.)** When a coding agent crashes mid-spec (`claude -p` process killed, machine restart, OOM, etc.), recovery happens at the next dispatcher tick:

| Crash state | Detection | Recovery |
|---|---|---|
| Crashed during `status:coding` (held claim) | `claim:agent-*` label is older than 30 min, no recent activity comment | Next claimant treats it as stale, removes the claim label, re-claims fresh |
| Crashed during `status:e2e-running` (e2e agent died mid-job) | `status:e2e-running` label is older than `e2e.timeout_minutes + 5` | Next e2e agent tick resets to `status:needs-e2e`, re-runs |
| Crashed during `status:review` (autofix loop exited) | Issue stuck in `status:review` with no recent commit and no `status:review-clean` after `idle_exit_ticks * poll_cadence` | Next tick resumes via `om-auto-continue-pr <PR#>` (v1.11.6 path); claim is restored if the review autofix had committed; otherwise restart from `status:e2e-passed` |
| Dispatcher itself crashed | All agents are in mid-state, no new spawns | Re-running `/om-orchestrate` (or its dispatcher script) detects existing in-flight issues and resumes — does NOT recreate them |
| Whole machine rebooted | All `claude -p` processes dead | User re-runs `/om-orchestrate`. Dispatcher inherits in-flight state from labels, spawns fresh agents to pick up. |

The system is **stateless beyond GitHub's labels and PR comments**. Any agent can be killed at any time and the next tick recovers from the labels alone. No filesystem state is required for correctness.

**Crash detection cadence**: stale-claim recovery runs every dispatcher tick (default 60s) and every e2e tick (default 30s). Worst-case detection latency = max(stale_threshold, tick_cadence) ≈ 30 minutes.

## Multi-PR conflict resolution — NEW

**(Addresses oneshot requirement #6.)** When two parallel coding agents land commits on different branches that touch the same files, the second-to-merge PR will hit a merge conflict. Resolution:

1. **Detection**: auto-merge step's `gh pr merge` returns `mergeable=false`. Issue moves to `status:blocked` with a structured comment naming the conflicting PR.

2. **Auto-resolve attempt** (single tick, low risk):
   - Coding agent on the blocked issue runs `git fetch origin develop && git rebase origin/develop`.
   - If rebase succeeds without conflicts → push, re-queue for e2e (in case the rebase changed semantics) → review → auto-merge.
   - If rebase has conflicts → escalate.

3. **Escalation path**: agent posts a lean comment summarizing the conflict (which files, which sibling PR), sets `status:blocked` + `human-review`, exits. Next tick of the dispatcher does not auto-pick this issue. Human resolves, removes `human-review`, work resumes.

**Prevention** (additive): the dispatcher, when releasing `status:backlog → status:ready`, can read the spec's `Files touched` section (when present in the run plan) and refuse to release two issues whose file sets overlap. v0.2 leaves this as a future hardening — initial implementation accepts conflict probability and resolves rather than prevents.

## Communication style — lean + secrets

### Lean (already established in v0.1, retained)

All GitHub surfaces (issue titles/bodies, PR titles/bodies, all comments) MUST default to simple non-technical language. Technical detail belongs in the repo — run plans, spec files, commit messages, code. Not in GitHub conversation.

Rules:
- Plain English, short sentences. *"Tests passed. Ready for review."* not stat tables.
- Reference repo paths, don't restate contents. *"See run plan in `.ai/runs/<file>.md`"*, then stop.
- Reference commits by purpose, not SHA dumps. *"Decline flow done."*
- When tech IS needed (specific bug, security finding), keep it short and lean — point to where the full detail lives in the repo, then stop.

### Secrets — NEW (analysis I4)

**Never paste secrets, tokens, `.env` content, raw credentials, or test-output strings that may contain them into PR comments, issue comments, or PR bodies.** This rule already exists in `om-auto-continue-pr/SKILL.md` Rules block; carried into every orchestration agent contract.

The e2e agent in particular: when tests fail with output that echoes env vars, the agent must redact before posting. Pattern: never `gh pr comment --body "$test_output"`. Always `gh pr comment --body "$one_line_summary"` with full output written to `/tmp/om-e2e-<#>.log` and an oblique reference like *"Full output in worktree log."*

If a test framework's failure output is structurally guaranteed not to leak env (verified by inspection per project), the project's `.ai/orchestration.yml` may declare `e2e.allow_failure_output: true` and the singleton may include the first 50 lines of failure output in the PR comment. Default off.

## Handoff comment shape

Every state transition that hands work to a different agent posts a short PR comment using the lean style. Example (coding → e2e):

```markdown
🤖 Handing off to e2e

Branch ready. Run plan: `.ai/runs/2026-05-07-prm-spec-06-scoring.md`.

Expected: most tests pass. One decline case may fail; details in run plan.

On pass → review. On fail → fix and re-queue.
```

That's it. No stat tables, no §-citations, no internal skill names, no SHA dumps. The next agent reads the comment for *intent*, then opens the run plan for *detail*.

## Spawning — Pattern A (per-tick fresh process via external dispatcher)

**(Addresses analysis C2 — picks Pattern A over the ambiguous v0.1 description.)**

Coding agents are short-lived: one tick = one fresh `claude -p` process fed `prompts/coding-agent.md`. Process exits naturally after the tick. The **outer dispatcher** script (`scripts/dispatcher.sh`, shown inline above) decides whether to spawn another and how many to keep in flight.

```bash
# Coding-agent spawn (per-tick)
nohup claude -p "$(cat $SKILL_ROOT/prompts/coding-agent.md)" \
  --dangerously-skip-permissions \
  > "/tmp/om-agent-coding-<ts>-<i>.log" 2>&1 &

# E2E singleton spawn (one long-lived process per orchestration run)
nohup claude -p "/loop ${E2E_POLL_CADENCE_SECONDS}s $(cat $SKILL_ROOT/prompts/e2e-agent.md)" \
  --dangerously-skip-permissions \
  > "/tmp/om-agent-e2e.log" 2>&1 &
```

The e2e agent is the one exception to per-tick — long-lived `/loop` process — because:
- E2E jobs are higher-latency (5-15 min); spawning a fresh process per poll is wasteful.
- The singleton invariant is easier to enforce with one persistent process than per-tick spawn.
- E2E `/loop` self-terminates via the `idle_exit_ticks` rule (the prompt embeds this exit logic).

**Critically: neither prompt file is registered in the Skill router.** `coding-agent.md` and `e2e-agent.md` are content the dispatcher reads at runtime. They never load at session start. They never appear in `/skills` listings. They cost zero session-context tokens.

Logs to `/tmp/om-agent-coding-<timestamp>-<i>.log` and `/tmp/om-agent-e2e.log`. The user can `tail -f` to watch. On macOS, log retention is the user's responsibility (cron or manual cleanup); future hardening could rotate.

**No cmux, no tmux, no terminal multiplexer.** Detached background processes are the deployment unit.

## Polling cadence

Coding agents: default 60s (configurable). E2E agent: default 30s (configurable). Both via `.ai/orchestration.yml`.

This is the right use of `/loop` cron mode (v1.11.5-compliant — fixed interval, polling external signal, fresh context per turn for coding agents). Different from v1.11.5 anti-pattern (self-pace `ScheduleWakeup` with no signal to watch).

GH API budget: 5 coding agents × 1 issue-list/min + 1 e2e × 2 issue-list/min ≈ 360 calls/h. 5000 calls/h authenticated limit. 7% utilization — comfortable headroom for spikes.

## Dependencies

`Blocked by #N` in issue body — well-known GitHub convention, parseable. The dispatcher (each tick) refuses to release `status:backlog → status:ready` until all `Blocked by` issues are closed.

PRM example (illustrative, not hardcoded):
- #1 (Agency foundation) — no deps
- #2 (WIP) → `Blocked by #1`
- #3 (Attribution) → `Blocked by #1, #2`
- #4 (WIC) → `Blocked by #1`
- #5 (RFP broadcast) → `Blocked by #1`
- #6 (RFP scoring) → `Blocked by #3, #5`
- #7 (CaseStudies) → `Blocked by #1`; soft dep on #5

After #1 ships, #2 + #4 + #5 + #7 release simultaneously — 4 in flight (within N=5 budget).

**Dependency-cycle prevention**: dispatcher refuses to release any issue with a cycle in its `Blocked by` chain. Logs and posts a `status:blocked` issue for human resolution.

## Phasing — compressed toward v1.14.0 oneshot goal

The user clarified: **v1.14.0 (oneshot-complete) is the goal, not three independent releases.** v1.12.0 and v1.13.0 are down-payments on v1.14.0, not standalone deliverables. Each release pulls forward as much v1.14.0 surface as possible so the final release is "turn on the last pieces," not "add a third major thing."

| Phase | Ship | Why this order | Version |
|---|---|---|---|
| **1 — Singleton mode + auto-merge for single-agent** | New `om-orchestrate` skill (with init / run / status / stop subcommands). E2E singleton via `prompts/e2e-agent.md`. Coding-agent prompt at `prompts/coding-agent.md` covers full lifecycle (claim → code → enqueue e2e → resume → review → **auto-merge**). `.ai/orchestration.yml` schema with all v1.14.0 fields populated. Label vocabulary. Bootstrap (`init` subcommand). Lean GitHub language baked into the new prompts (also retroactively patches the auto-* trio's verbose templates — see "v1.11.7 retired"). `om-implement-spec` Step 8 patched additively (singleton-detect fallback). **Cost telemetry instrumented from day 1.** | Cheapest validation. Fixes v1.11.5 root cause (sleeping). Auto-merge in single-agent mode is trivial (no conflict possible) and ships now so v1.14.0 doesn't have to add it. Tests on PRM Spec #6 end-to-end (single-agent + singleton + auto-merge). | v1.12.0 |
| **2 — Multi-agent + claim protocol + conflict auto-rebase** | Outer dispatcher (`scripts/dispatcher.sh`) keeps N coding agents in flight. Claim protocol (corrected single-instance label + verify-after-add). Multi-PR conflict auto-rebase on merge failure. Cost baseline measured against Phase 1 numbers. | Turns on parallelism for the already-merging system. Tests on PRM Specs #6 + #7 in parallel + auto-merge. | v1.13.0 |
| **3 — Failure recovery + Projects v2 view** | Full failure-recovery rules (stale-claim recovery, mid-job e2e crash, dispatcher crash, machine reboot — see Failure recovery section). GitHub Projects v2 status field migration with kanban view. | Closes the oneshot loop. Auto-merge already shipped in v1.12.0; multi-agent already shipped in v1.13.0. v1.14.0 is "turn on the last two pieces." Validated by killing agents mid-spec and watching the system recover; first oneshot run on a non-PRM OM project. | v1.14.0 |

**v1.11.7 retired as its own release.** Per the context-budget rule, the lean GitHub language style ships as part of v1.12.0's new agent prompts (which are lean from the start) AND v1.12.0's patches to the existing auto-* trio's verbose summary templates. Saves a release-ceremony round; same end state.

**Total estimated wall-time to v1.14.0**: ~1 week of focused work (Phase 1 ~2 days, Phase 2 ~3 days, Phase 3 ~1-2 days).

**Validation surface throughout**: PRM Specs #6 + #7 carry the protocol through Phase 1 + Phase 2; the next greenfield OM project is the v1.14.0 oneshot proving ground.

## BC strategy — v1.11.6 → v1.12.0 transition

**(Addresses analysis C3.)** v1.12.0 ships `om-implement-spec` with new behavior: when ready for tests (Step 8), instead of running `yarn test:integration:ephemeral` inline, the agent enqueues to e2e via labels. **Without an e2e singleton spawned, this would silently break.**

Mitigation — additive patching with singleton-detect fallback:

```
om-implement-spec Step 8 (revised):

1. Check if .ai/orchestration.yml exists and an e2e singleton is alive.
   - "Alive" = sentinel file /tmp/om-e2e-singleton.pid exists AND the
     process named in it is running AND the singleton has posted a
     comment within the last (e2e_poll_cadence_seconds * 4) seconds.

2. If alive: enqueue via label transition (status:coding → status:needs-e2e),
   post handoff comment, exit. The singleton picks up.

3. If NOT alive: fall back to inline run. Same behavior as v1.11.6.
   Log a one-line note: "E2E singleton not detected; running inline.
   Run /om-orchestrate init to enable orchestration mode."
```

v1.12.0 ships as additive: nothing breaks for users who haven't opted in. Users who do opt in get the singleton's benefits.

Existing PRs (PR #4, PR #5) won't have the new label vocabulary. No retroactive labeling. v1.12.0 applies only to new issues created via `om-orchestrate` or via existing skills' issue-creation paths once those are patched in v1.13.0.

## Verification — how we'd know each phase works

**Phase 1 (e2e singleton, single coding agent):**
- A future spec implementation run shows the coding agent calling `gh issue edit --add-label status:needs-e2e` then exiting, instead of running `yarn test:integration:ephemeral` inline.
- The e2e singleton agent posts results as a PR comment in lean style.
- Wall-time on a single-spec run is *not worse* than today (proves the singleton overhead is acceptable).
- Any user without `om-orchestrate init` run sees identical v1.11.6 behavior (proves additive BC).

**Phase 2 (parallel coding):**
- Running PRM Specs #6 + #7 in parallel completes in ≤ 1.5× the time of either spec alone.
- No claim conflicts surface in agent logs (proves claim protocol works).
- E2E singleton processes 2+ jobs serially without interleaving / fixture pollution.
- Conflict between two parallel PRs auto-resolves in the rebase path ≥ 70% of the time (otherwise escalates cleanly to human).

**Phase 3 (auto-merge + recovery):**
- A full PRM-style run from `/om-orchestrate <app-spec>` to all-PRs-merged completes with zero human keyboard input.
- Killed-mid-spec test: `kill -9` a coding agent during `status:coding`. Within 30 min, a fresh agent picks up the issue and resumes. Nothing is lost.
- Auto-merge respects `human-review` label: applying it pauses the merge until removed.

## Cost telemetry baseline (Phase 2 prerequisite)

**(Addresses analysis I2.)** The v0.1 cost estimate ($500/PRM-run) was hand-wavy. Before Phase 2 ships, instrument and measure:

- Per-tick API cost (input tokens, output tokens, cache hit rate)
- Per-spec total cost (sum of all ticks across all agents involved)
- Wall-time per spec
- Per-agent process count over time

Use Phase 1's single-agent runs on PRM #6 as the baseline. Multiply through to estimate Phase 2 parallel cost. **Phase 2 ships only after baseline measurement** — otherwise we're guessing at the budget for community users.

## Risks (updated)

| Risk | Mitigation |
|---|---|
| **GitHub API rate limits at high N** | Documented budget (5 agents × 1 poll/min ≈ 360 req/h). Webhook fallback path acknowledged for N>10. |
| **Comment noise on long-lived issues** | Single 🤖 status comment edited (not appended). Lean-language rule enforced. |
| **Race on issue claim** | Single-instance `claim:*` label + verify-after-add + lowest-timestamp tiebreaker (see "Claim protocol"). |
| **E2E singleton crashes mid-job** | Stale label detection > `timeout + 5min`. Recovery via reset to `status:needs-e2e`. |
| **Coding agent orphans an issue mid-flight** | Stale claim recovery (30min). Agent re-verifies claim ownership on every tick. |
| **Multi-PR conflict** | Auto-rebase first; on failure, escalate to `status:blocked` + `human-review`. |
| **Dependency cycles** | Dispatcher refuses to release; logs; surfaces as `status:blocked`. |
| **v1.11.6 → v1.12.0 silent break** | Singleton-detect-and-fallback in `om-implement-spec` Step 8. |
| **Cost** | Baseline before Phase 2. Telemetry instrumented in Phase 1. |
| **Project incompatibility** | `.ai/orchestration.yml` schema. Bootstrap (`om-orchestrate init`) detects shape, generates stub. |
| **Process leak** | `idle_exit_ticks` rule in dispatcher and e2e agent — exit after N empty polls. |
| **Secrets leakage in PR comments** | Communication style § Secrets — never paste env vars or full test output. |

## Out of scope (v0.2 — these wait for later)

- **GitHub Projects v2 migration** — labels-only is sufficient through Phase 2; Projects v2 is a Phase 3 visualization upgrade.
- **GitHub Actions e2e runner** — local detached process is faster (5min vs 10-15min cold-start). GH Actions becomes a hardening upgrade if/when the protocol is proven.
- **Cross-repo orchestration** — single-repo only. Cross-repo introduces auth + dependency-resolution complexity not worth solving now.
- **Webhook-driven dispatch** — polling at 1m sufficient for N≤10. Webhooks become a perf optimization to revisit if/when N>10. Migration path: replace `/loop 1m` with a small HTTP receiver (`gh webhook forward`) firing the next tick on label-change events.
- **Concurrent e2e** — explicitly singleton. Justification: ephemeral runner provisions its own DB/services; concurrent runs port-conflict and pollute fixtures. Moot until a containerized per-job runner exists.
- **Parallel CTO (spec writing)** — payoff is small (CTO is 1-2h once per app). Reordered out of v1.14.0; would be a v1.15.0+ candidate if and only if the CTO phase becomes a measured bottleneck.

## Cross-link

- v1.11.5 (`/loop` self-pace anti-pattern) — fixed *symptom* (agents sleeping); this design fixes *cause* (no peer to yield to).
- v1.11.6 (post-PR review gate) — fixed *symptom* (review skipped); this design integrates review as a peer agent in the state machine.
- v1.11.3 (duplicate-work prevention) — labels protocol generalizes the existing `in-progress` lock used by `auto-create-pr` / `auto-continue-pr`. The new `claim:*` primitive fixes the race condition that v1.11.3's PR-level lock didn't cover.
- **v1.11.7 — RETIRED as its own release.** Per context-budget rule, the lean GitHub communication style ships as part of v1.12.0 (new agent prompts are lean from inception, plus v1.12.0 patches the existing auto-* trio's verbose summary templates). Memory rule already saved (`feedback_lean_github_communication.md`); the codification ships with v1.12.0's other patches.

PRM Specs #6 and #7 ARE the validation surface for this design. Phase 1 (v1.12.0) validates on #6 (single agent + singleton + auto-merge). Phase 2 (v1.13.0) validates on #7 (multi-agent + parallel + conflict auto-rebase). Phase 3 (v1.14.0) validates on the next greenfield OM project (oneshot end-to-end with failure recovery).

## Context-budget summary

| Surface | Cost at session start | When loaded |
|---|---|---|
| `om-orchestrate` skill frontmatter (the only new top-level entry) | ~150 tokens | Always (any project with om-superpowers) |
| `references/*.md` (agent contracts, claim protocol, dispatcher, recovery, etc.) | 0 | On-demand when `om-orchestrate` reads them |
| `prompts/*.md` (coding-agent, e2e-agent, merge-agent) | 0 | On-demand when dispatcher feeds to `claude -p` |
| `scripts/dispatcher.sh` | 0 | Executed by `om-orchestrate run`, never loaded as context |
| Patches to `om-implement-spec`, `om-cto`, auto-* trio | ~0-10 tokens each (small Rules/Step additions) | Only when those skills are invoked |

**Total session-start tax for the entire orchestration system: ~150 tokens** — equivalent to one small skill, not five.

This is the right place to enforce the discipline. v1.12.0 ships ~150 token tax; v1.13.0 + v1.14.0 should add **zero net tokens** to session start (all new logic in references and prompts). Drift will be caught during code review on each release.

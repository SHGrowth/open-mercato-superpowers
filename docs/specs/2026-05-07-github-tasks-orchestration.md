# GitHub-Tasks Orchestration — fully autonomous parallel agent fleet

**Date:** 2026-05-07
**Status:** Design — pending review
**Owner:** Mat (CEO)
**Driven by:** PRM 7-spec implementation; v1.11.5 forensic (sleeping anti-pattern); v1.11.6 forensic (post-PR review gap); user design proposals 2026-05-07

## TL;DR

om-superpowers becomes a fleet of agents coordinated entirely through **GitHub Issues + labels + PR comments**. No filesystem queue, no cmux ceremony, no IPC daemon. The user runs one command (`/om-orchestrate <app-spec-or-execution-plan>`); the system spawns:

- **N coding agents** (default 5; configurable), one per task in flight
- **1 e2e singleton agent** that owns `yarn test:integration:ephemeral` and processes the e2e queue serially

All agents are detached `claude -p` background processes. They communicate via `gh issue` / `gh pr` labels and structured comments. They exit naturally when their task completes. The fleet is fully autonomous from "App Spec exists" through "all PRs merged" — humans only intervene on tasks explicitly tagged `human-review`.

## Why this design

Three failure modes from prior PRM forensics drove this:

1. **v1.11.5 — `/loop` self-pace burns wall-time on idle ticks.** Root cause: agents were waiting on something (long e2e runs) but had no way to *yield* their context to a different worker. They slept instead of yielding.
2. **v1.11.6 — `om-implement-spec` ships PRs without real review.** Root cause: the implementer's "done" was tied to its own checklist, not to a downstream gate that another agent enforced.
3. **PRM serial implementation is slow.** 7 specs × ~2.5h sequential each = ~14 hours wall-time. Three of those specs are independent post-MVP. Most of that time is one agent waiting for tests/CI while another agent could be coding.

All three are symptoms of the same shape: **one agent doing everything, blocking on its own gates, with no peer to hand work to.** Tasks-on-GitHub turns this into a fleet with explicit hand-offs.

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
- **User-staged (rejected)**: requires manual issue creation per spec; loses the "spec → task → PR → merge" autonomous loop; reduces to a fancy task tracker.

Veto channel preserved via `human-review` label. Apply it to any issue and the fleet skips that issue until the label is removed. No code changes needed to halt — just label.

## State machine (label vocabulary)

Single-axis status field, encoded as labels until Projects v2 migration:

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
| `status:review-clean` | Review clean; ready to merge | review agent | merging agent |
| `status:blocked` | Real blocker, needs human | any agent on irrecoverable error | human |
| `human-review` | Pause; do not advance until removed | human | human |

**Atomicity:** GitHub label add/remove is atomic. The "claim" pattern (`gh issue edit --add-assignee $USER && gh issue edit --remove-label status:ready --add-label status:coding`) races safely because GitHub returns 422 if another agent already claimed.

## Agent contracts

### `om-orchestrate` — the entry-point command

Invoked by the user. Reads `app-spec/app-spec.md` or `.ai/specs/EXECUTION-PLAN.md`. For each spec without a corresponding open issue, opens one with:

- Title: `Spec #N — <feature>`
- Body: link to spec file, `Blocked by #X` line for each dep, `Tracking plan: <run-plan-path>` if exists
- Labels: `status:backlog` (or `status:ready` if no deps)
- Assignees: none yet

Then spawns the fleet:

```bash
# Spawn N coding agents — each picks up the next ready issue
for i in $(seq 1 ${OM_PARALLEL_N:-5}); do
  nohup claude -p "/om-pr-tick" --dangerously-skip-permissions \
    > /tmp/om-agent-coding-$i.log 2>&1 &
done

# Spawn 1 e2e singleton
nohup claude -p "/om-e2e-tick" --dangerously-skip-permissions \
  > /tmp/om-agent-e2e.log 2>&1 &
```

Agents run their respective `/loop 1m` (cron mode) tick prompts. They exit when their task is done; if the queue still has work, the next coding agent invocation (cron tick fire) picks up the next ready issue. The e2e agent runs as long as any issue has `status:needs-e2e` or `status:e2e-running`.

### Coding agent — `/om-pr-tick`

Polls for work via `gh issue list`. For each tick:

```
1. Find issue: gh issue list --label status:ready --no-deps --jq 'first'
   - "no-deps" = no `Blocked by #N` for an open issue
   - If no candidate, exit (next cron tick will retry)

2. Claim:
   - gh issue edit --add-assignee $USER
   - gh issue edit --remove-label status:ready --add-label status:coding
   - On 422 race conflict: pick next candidate

3. Work:
   - If no PR linked yet: invoke om-implement-spec or om-auto-create-pr
     to start the run plan. Open PR with `Closes #<issue>` in body.
   - If PR linked: invoke om-auto-continue-pr <PR#> to resume
   - When ready for tests: yield via the handoff protocol (below)

4. Handoff to e2e:
   - Stage commits, push branch
   - gh issue edit --remove-label status:coding --add-label status:needs-e2e
   - gh issue comment <#> --body "<structured handoff comment>"
   - Exit

5. Resume after e2e:
   - On next tick, see issue with status:e2e-passed or status:e2e-failed
     assigned to me → claim, route to fix or to review
```

### E2E singleton agent — `/om-e2e-tick`

```
1. Acquire singleton lock:
   - gh issue list --label status:e2e-running → if any exist owned by another agent, exit (another e2e agent is active; we're a duplicate)
   - Otherwise we're free to claim

2. Find next job:
   - gh issue list --label status:needs-e2e --jq 'first'
   - If none, exit (next cron tick will retry)

3. Claim:
   - gh issue edit --remove-label status:needs-e2e --add-label status:e2e-running

4. Run:
   - Check out the linked PR's branch into a worktree
   - Run yarn test:integration:ephemeral with required env (OM_PRM_WIC_IMPORT_SECRET etc.)
   - Capture results

5. Post results:
   - gh pr comment <PR#> --body "<test results, failures, links>"
   - gh issue edit --remove-label status:e2e-running --add-label status:e2e-passed (or status:e2e-failed)

6. Exit; next cron tick picks up the next needs-e2e
```

### Review agent — uses existing `om-auto-review-pr`

When coding agent's post-e2e tick sees `status:e2e-passed`, it transitions to `status:review` and invokes `om-auto-review-pr <PR#>` (which itself runs `om-ds-guardian REVIEW`). On clean verdict: label `status:review-clean`. On findings: agent stays on the issue, applies autofix, re-queues for e2e.

This step uses v1.11.6's mandate — no separate review agent process needed; the coding agent invokes the review skill at the right state.

## Handoff comment shape

Every state transition that hands work to a different agent posts a structured PR comment (also mirrored on the issue). One blob, parseable, collapsible.

```markdown
🤖 Handoff — coding → e2e (issue #42, PR #87)

**Last commit:** abc1234 — "feat(prm): T6 scoring widget complete"
**Branch:** feat/prm-spec-06-scoring
**Files in flight:** None (all staged, pushed)
**Expected outcome:** §9.1 #1–#3 should pass; §9.4 #20 may fail (decline edge case)
**Resume instructions:**
- On status:e2e-passed → run `om-auto-review-pr 87` and apply autofix
- On status:e2e-failed with §9.4 #20 → check `RfpDeclineService.unsubmit` guard

🤖 End handoff
```

The next agent reads the most recent `🤖 Handoff` comment to pick up. Same shape that `om-auto-continue-pr` already uses for human-driven resume.

## Spawning — no cmux required

`claude -p` runs detached. Logs to `/tmp/om-agent-*.log`. Exits when its session ends. Re-spawn happens on the next cron tick from a different fresh process. No long-running session state, no terminal multiplexer.

If the user wants to watch logs, they `tail -f /tmp/om-agent-coding-*.log`. If they want to see status, they look at the GitHub Project board (or `gh issue list --json status`). Two modes for two audiences.

## Polling cadence — `/loop 1m` (cron mode)

This is the right use of `/loop` cron mode (v1.11.5-compliant — fixed interval, polling external signal, fresh context per turn). Different from the v1.11.5 anti-pattern: that was self-pace `ScheduleWakeup` with no signal to watch. This is textbook polling.

Cadence rationale:
- 1m for coding agents — enough to catch label transitions without burning API quota
- 30s for e2e agent — slightly tighter because e2e jobs are higher-latency and we want pickup latency under 1 min
- GH API rate limits: 5000 req/h authenticated. 5 coding agents × 1 poll/min × 1 issue-list call = 300 calls/h. Well within budget.

## Dependencies

`Blocked by #N` in issue body — well-known GitHub convention, parseable. The dispatcher (or any tick) refuses to release `status:backlog → status:ready` until all `Blocked by` issues are closed.

For PRM:
- #1 (Agency foundation) — no deps
- #2 (WIP) → `Blocked by #1`
- #3 (Attribution) → `Blocked by #1, #2`
- #4 (WIC) → `Blocked by #1`
- #5 (RFP broadcast) → `Blocked by #1`
- #6 (RFP scoring) → `Blocked by #3, #5`
- #7 (CaseStudies) → `Blocked by #1`; soft dep on #5

After #1 ships, #2 + #4 + #5 + #7 can all release simultaneously — 4 in flight.
After #5 + #3 close, #6 releases. After #5 closes, #7's soft dep is satisfied.

## Phasing

| Phase | Ship | Why first | Status |
|---|---|---|---|
| **1 — E2E singleton + label vocabulary** | New `om-e2e-runner` skill, label set, `om-implement-spec` patched to enqueue instead of run inline | Cheapest validation, narrowest scope, fixes the v1.11.5 root cause (sleeping while waiting). Can test on PRM #6 in single-agent mode before adding parallelism. | This spec |
| **2 — Coding agent + tick protocol + dispatcher** | `om-orchestrate` spawn command, `/om-pr-tick` polling loop, claim protocol | Builds on phase 1's labels. Tested when 2 PRs are in flight (e.g., #6 and #7 simultaneously). | Future spec |
| **3 — Parallel decomposition (CTO phase)** | `om-cto` learns to fan out spec writing across 5 agents | Smallest payoff (CTO phase is 1-2h once); can wait. | Future spec |

Each phase ships as its own version (v1.12.0, v1.13.0, v1.14.0).

## Verification — how we'd know each phase works

**Phase 1 (e2e singleton):**
- A future spec implementation run shows the coding agent calling `gh issue edit --add-label status:needs-e2e` then exiting, instead of running `yarn test:integration:ephemeral` inline.
- The e2e singleton agent posts results as a PR comment.
- Wall-time on a single-spec run is *not worse* than today (proves the singleton overhead is acceptable).

**Phase 2 (parallel coding):**
- Running PRM Specs #6 + #7 in parallel completes in ≤ 1.5× the time of either spec alone (proves real parallelism, not Amdahl-degraded).
- No PR claim conflicts (proves the 422-race claim protocol works).
- E2E singleton processes 2+ jobs serially without interleaving / pollution.

**Phase 3 (parallel CTO):**
- App Spec decomposition into 7 specs completes in ≤ 30 min (vs current ~1-2h sequential).
- All 7 specs pass cross-validation review the first time (proves parallel writers stayed coherent).

## Risks

| Risk | Mitigation |
|---|---|
| **GitHub API rate limits at high N** | Documented budget (5 agents × 1 poll/min = 300 req/h). If we ever push to N=20, switch to webhook-driven instead of polling. |
| **Comment noise on long-lived issues** | Use a single 🤖 Status comment that gets edited (not appended). Keep handoff blobs collapsible. |
| **Race on issue claim** | GitHub label add is atomic. Claim protocol does add-then-verify; on conflict, agent picks next candidate. |
| **E2E singleton crashes mid-job** | Job stays in `status:e2e-running`. Next e2e agent tick (after spawn) sees it, checks the timestamp on the label, treats >15min stale as recoverable, re-runs. |
| **Coding agent spawns mid-claim and orphans the issue** | On every tick, agent re-verifies it owns the issue's `assignees`. If not, exits. |
| **Dependency cycles** | Dispatcher refuses to release any issue with a cycle in its `Blocked by` chain; logs and posts to a `status:blocked` issue for human resolution. |
| **Cost** | Each cold-start agent re-reads ~15k tokens of cache + skills. At 5 agents × 30 ticks/spec × $0.50/tick ≈ $75 per spec. PRM 7-spec run ≈ $500 total. Worth measuring after phase 2 before scaling. |

## Out of scope (this design spec)

- **GitHub Projects v2 migration** — labels-only is sufficient for v1; Projects view is a visualization upgrade for humans.
- **GitHub Actions e2e runner** — local cmux/process is faster (5min vs 10-15min cold-start). GH Actions becomes a hardening upgrade if/when the protocol is proven.
- **Cross-repo orchestration** — single-repo only for v1. Cross-repo introduces auth + dependency-resolution complexity not worth solving now.
- **Webhook-driven dispatch** — polling at 1m is sufficient for N≤5. Webhooks are a perf optimization to revisit if N>10.
- **Concurrent e2e** — explicitly singleton. No design for parallelizing the integration runner. Justification: ephemeral runner provisions its own DB/services; concurrent runs port-conflict and pollute fixtures. Moot until a containerized per-job runner exists.

## Cross-link

- v1.11.5 (`/loop` self-pace anti-pattern) — fixed *symptom* (agents sleeping); this design fixes *cause* (no peer to yield to).
- v1.11.6 (post-PR review gate) — fixed *symptom* (review skipped); this design integrates review as a peer agent in the state machine.
- v1.11.3 (duplicate-work prevention) — labels protocol here generalizes the existing `in-progress` lock used by `auto-create-pr` / `auto-continue-pr`.

If a v1.11.7 emerges from PRM Spec #6 + #7 implementation pain, that's signal Phase 2 should be brought forward. If sequential Specs #6 + #7 ship cleanly under v1.11.6, this design can wait until the next greenfield app where parallelism's payoff is bigger.

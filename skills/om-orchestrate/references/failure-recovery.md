# Failure recovery

The system is **stateless beyond GitHub's labels and PR comments**. Any agent (including the dispatcher) can be killed at any time and the next tick recovers from labels alone. No filesystem state is required for correctness.

**Phase 1 (v1.12.0)** ships the recovery contracts but exercises only the simple cases (single-agent + e2e singleton crashed). Full multi-failure scenarios from Phase 3 (v1.14.0) are documented here from day 1 so the design stays coherent.

## Recovery rules per failure mode

| Crash state | Detection signal | Recovery action |
|---|---|---|
| **Coding agent died holding a claim** | `claim:agent-*` label is older than `recovery.stale_claim_minutes` (default 30 min) AND the issue lacks `status:coding` | Next claimant runs `clean_stale_claims` (see `references/claim-protocol.md`), removes the stale claim, claims fresh. |
| **Coding agent died after taking `status:coding`** | `status:coding` AND `claim:agent-*` is stale AND no recent commit on the linked PR's branch | Stale-claim sweep removes both labels. Next coding-agent tick treats the issue as resumable from prior state — invokes `om-auto-continue-pr <PR#>` if PR exists, else `om-implement-spec` from scratch. |
| **E2E agent died mid-job** | `status:e2e-running` label is older than `e2e.timeout_minutes + 5` minutes (default 20) | E2E singleton's tick (Step 1 of `references/agent-contracts.md` § E2E) resets to `status:needs-e2e`. Re-run on next tick. |
| **E2E singleton process died entirely** | No `om-agent-e2e` process running AND issues exist with `status:needs-e2e` or `status:e2e-running` | Dispatcher's main loop detects via `pgrep -f om-agent-e2e`; respawns. Stale-running labels reset on the next e2e tick. |
| **Coding agent died during `status:review`** | `status:review` label older than `idle_exit_ticks * poll_cadence_seconds` AND no recent push | Next coding-agent tick claims (claim protocol), routes through `om-auto-continue-pr <PR#>`. If autofix had committed before the crash, the new agent picks up from the commit; otherwise restarts review from `status:e2e-passed`. |
| **Coding agent died during merge** | `in-progress` label on PR with no `status:review-clean` removal AND PR not closed AND `in-progress` is older than 10 min | Stale `in-progress` sweep on the PR (separate from issue-claim sweep). Next coding-agent tick re-attempts merge if `merge.required_checks` are still green. |
| **Dispatcher itself crashed** | All `om-agent-*` PIDs dead AND no progress on any issue label for `idle_exit_ticks` ticks | User re-runs `/om-orchestrate run`. Idempotent — recovers from labels. Open issues continue from their current label state. |
| **Whole machine rebooted** | All processes dead | Same as dispatcher crash. User re-runs `/om-orchestrate run`. |

## Crash detection cadence

- **Stale-claim sweep** runs at the start of every coding-agent tick (default every 60s).
- **Stale-e2e-running sweep** runs at the start of every e2e tick (default every 30s).
- **Stale `in-progress` sweep** runs in the dispatcher's main loop (default every 60s).
- **Worst-case detection latency** = max(stale_threshold, tick_cadence) ≈ 30 minutes for a stale claim, 20 minutes for stale e2e.

These can be tuned per-project via `.ai/orchestration.yml`'s `recovery` section. Don't go too aggressive — a coding agent that genuinely needs 25 minutes to think through a hard spec phase shouldn't get its claim stripped at minute 5.

## What is *not* a failure (don't recover)

| Looks like a problem | Actually | Don't recover |
|---|---|---|
| Issue stuck at `status:blocked` | Hit a real blocker; needs human | The system intentionally pauses. Recovery would loop. |
| Issue with `human-review` label | Human paused it | Hands off; do not auto-resume. |
| Open PR with no recent commits | Could be coding-agent-dying-mid-claim, OR could be deliberately paused | Distinguish via the *label* state on the issue, not the PR. If issue is `human-review` or `status:blocked`, don't touch. |
| Empty `gh issue list --label status:ready` | Queue is just empty, not a failure | Idle counter increments; eventual graceful exit. |
| `gh` API rate limit hit | Transient | Backoff (exponential, max 5 min); resume. Do not respawn agents — wait. |

## What recovery does not solve (Phase 1 limits)

These are documented for Phase 3 awareness:

- **Two coding agents simultaneously progress past stale-claim recovery.** Mitigated by the verify-after-add step in the claim protocol; theoretically a 200ms-window race could let two pass; the second loser self-evicts on its next tick when it sees its claim is no longer the lowest-timestamp.
- **Dispatcher crashed while issues were mid-promotion** (`status:backlog → status:ready`). Re-running the dispatcher re-evaluates dependencies; safe.
- **Network partition during merge.** PR may end up merged on origin but the dispatcher didn't see the response. Next tick checks `gh pr view <PR#> --json state` — if `merged`, close the issue and proceed; if not, re-attempt.

## Manual override

The user can always set `human-review` on any issue to pause it. The user can also kill all `om-agent-*` processes and re-run `/om-orchestrate stop` then `/om-orchestrate run` for a clean restart. No state corruption — labels are the truth.

For a *full reset* on an issue (drop all orchestration state), the user runs:

```bash
gh issue edit <#> --remove-label "$(gh issue view <#> --json labels --jq '.labels[].name | select(startswith("status:") or startswith("claim:"))' | tr '\n' ',')"
```

…then re-applies `status:ready` if they want orchestration to pick it up again. This is a manual escape hatch documented for the user's own toolkit.

## Phase 3 additions (not in v1.12.0)

- **Recovery sweeps in dispatcher main loop** — currently every coding-agent does its own claim sweep; Phase 3 may centralize this.
- **Crashed-during-merge specifically** — Phase 1 escalates to human; Phase 3 adds auto-rebase + retry.
- **Network-partition replay** — Phase 1 retries naively; Phase 3 may add a retry budget per operation type.

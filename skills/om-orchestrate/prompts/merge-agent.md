# Merge agent — content fragment for the coding agent

Phase 1 (v1.12.0) does not run a separate merge agent process. The merge logic ships inside `prompts/coding-agent.md` § Step 4 — From `status:review-clean`. This file is a *content fragment* the coding agent prompt incorporates by reference, not a standalone prompt.

If a future Phase needs a dedicated merge process (e.g., merge contention becomes a real issue at high N), this content extracts cleanly into `prompts/merge-agent.md` as its own prompt.

## When triggered

Coding agent's tick sees a claimable issue with `status:review-clean`. Steps from `prompts/coding-agent.md` § 4 / `status:review-clean`:

1. **Verify required checks**.
2. **Apply `in-progress` on the PR** (auto-* trio's lock).
3. **Run `gh pr merge`** per `merge.strategy`.
4. **On success**: close issue, post lean confirmation, remove `in-progress`.
5. **On conflict**: set `status:blocked`, post conflict info, exit. (Phase 2 adds auto-rebase here.)

## What this fragment defends against

- **Concurrent merge attempts.** The PR's `in-progress` label is the auto-* trio's lock. By taking it briefly during merge, this prevents `om-auto-review-pr` (or any other auto-skill) from racing on the same PR.
- **Stale required-checks state.** `gh pr checks <PR#>` is read at merge moment. If a check went red between `status:review-clean` and the merge attempt, the merge does not proceed.
- **Race against human merge.** Unlikely but possible: human clicks merge while the agent is mid-flow. `gh pr merge` returns non-zero on already-merged PR. Agent treats already-merged as success: closes the issue, exits.

## What this fragment does *not* do

- **Auto-rebase on conflict.** Phase 2 territory. Phase 1 escalates to human via `status:blocked`.
- **Override `merge.required_checks`.** No bypass logic. If checks are red, the merge waits.
- **Bypass `human-review` veto.** If `human-review` is on the issue, the coding agent never reaches this branch.

## Telemetry

Write a jsonl line to `$OM_TELEMETRY_LOG_DIR/merge-$(date +%F).jsonl`:

```json
{"ts": "2026-05-07T12:30:00Z", "agent": "merge", "issue": 42, "pr": 87, "outcome": "merged"}
```

Outcomes: `merged`, `conflict`, `checks_red`, `already_merged`, `error`.

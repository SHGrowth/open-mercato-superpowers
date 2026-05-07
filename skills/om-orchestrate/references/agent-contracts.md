# Agent contracts

Behavior of the three agent types. **None are registered as skills** — they are content the dispatcher reads from `prompts/*.md` and feeds to background `claude -p` processes. They never tax session-start context.

## Coding agent (`prompts/coding-agent.md`)

**Lifetime:** one tick per process invocation. Picks up an issue, does one unit of work, exits.

**Tick steps:**

1. **Find work.** Look for an issue I can claim:
   - First check: do I have an open `claim:agent-<my-id>` label on any issue? If yes, that's my work — resume.
   - Otherwise: `gh issue list --label "status:ready,status:e2e-passed,status:e2e-failed" --no-deps --jq 'first'`. "No-deps" means no `Blocked by #<open-issue>` references.
   - If nothing claimable, exit (the dispatcher will or won't spawn another tick).

2. **Claim** (per `references/claim-protocol.md`).
   - On race-loss, exit silently. Dispatcher will spawn another tick if needed.

3. **Work** based on the issue's current label state:
   - `status:ready` (fresh): invoke `om-implement-spec` or `om-auto-create-pr` per the spec linked in the issue body. Open a PR with `Closes #<issue>` in the body.
   - `status:e2e-passed`: invoke `om-auto-review-pr <PR#>` in autofix mode. On clean → set `status:review-clean`. On findings → autofix loop; eventually re-queue for e2e via Step 4.
   - `status:e2e-failed`: read the e2e agent's PR comment with the failure summary. Fix the failures. Re-stage, push, re-queue for e2e via Step 4.
   - `status:review-clean`: this is the merge moment. See Auto-merge below.

4. **Yield to e2e** when ready for tests:
   - Stage commits, push branch.
   - `gh issue edit <#> --remove-label status:coding --add-label status:needs-e2e`.
   - Post a lean handoff comment (see § Handoff comment shape below).
   - Exit.

5. **Auto-merge** when `status:review-clean`:
   - Verify all `merge.required_checks` (from `.ai/orchestration.yml`) are green via `gh pr checks <PR#>`. If not all green → re-queue for e2e (or set `status:blocked` if non-test failure).
   - Apply `in-progress` on the PR (auto-* trio's lock — claims the merge action against any concurrent auto-skill).
   - `gh pr merge <PR#> --${merge.strategy} --delete-branch=${merge.delete_branch}`.
   - On success: close the issue, post a short comment ("Merged. Spec done."), remove the PR's `in-progress` label.
   - On merge conflict: set `status:blocked` on the issue, post the conflict info as a comment, leave the PR open. Phase 2 adds auto-rebase here; Phase 1 escalates to human.

6. **Exit conditions** (any of):
   - Yielded successfully (handoff complete).
   - Merge succeeded (issue closed).
   - No claimable work this tick.
   - Race-lost on claim attempt.
   - Irrecoverable error → set `status:blocked` + post error comment + exit.

## E2E singleton (`prompts/e2e-agent.md`)

**Lifetime:** long-lived `/loop ${E2E_POLL_CADENCE_SECONDS}s` process. Exits when no work for `idle_exit_ticks` consecutive ticks.

**Tick steps:**

1. **Singleton lock check.** Read all open issues with `status:e2e-running`. If any have a "running" timestamp (from the labeling agent's comment) older than `e2e.timeout_minutes + 5`, reset to `status:needs-e2e` (stale recovery — see `references/failure-recovery.md`).

2. **Find next job.** `gh issue list --label "status:needs-e2e" --state open --jq 'first'`. If none, increment idle counter; if idle ≥ `idle_exit_ticks`, run `/loop stop` and exit. Otherwise sleep until next tick.

3. **Claim.** `gh issue edit <#> --remove-label status:needs-e2e --add-label status:e2e-running`. Post a comment: *"Tests starting."*

4. **Run.**
   - `git worktree add` for the linked PR's branch.
   - Read `e2e.command`, `e2e.required_env`, `e2e.timeout_minutes` from the loaded config.
   - Verify required env present; if missing → `status:blocked` + lean error comment, exit job.
   - Execute the command, capturing output to `/tmp/om-e2e-<#>.log`.
   - Apply timeout — kill if exceeds `e2e.timeout_minutes`.

5. **Post results** (lean style):
   - On pass: `gh pr comment <PR#> --body "Tests passed."` then `--add-label status:e2e-passed --remove-label status:e2e-running`.
   - On fail: `gh pr comment <PR#> --body "Tests failed: <one-line summary>. Full output: /tmp/om-e2e-<#>.log on the runner host."` then `--add-label status:e2e-failed`.
   - On timeout: `--body "Tests exceeded ${e2e.timeout_minutes}min. Killed."` then `--add-label status:e2e-failed`.
   - **Never paste env vars or full test output that may contain secrets.** Per `e2e.allow_failure_output: false` default, the agent paraphrases failure to one line.

6. **Cleanup.** `git worktree remove`. Continue to next tick.

## Merge agent (Phase 1: ships as part of coding-agent)

The merge logic is included in the coding agent's tick when it sees `status:review-clean` (Step 5 above). No separate process. `prompts/merge-agent.md` is a *content fragment* the coding agent's prompt includes — same context budget, cleaner separation in source.

Phase 3 may break this out into a dedicated singleton process if merge contention becomes a real issue. v1.12.0 keeps it inline.

## Handoff comment shape

Every state transition that hands work to a different agent posts a short PR comment using lean language. Example (coding → e2e):

```markdown
🤖 Handing off to e2e

Branch ready. Run plan: `.ai/runs/<plan-file>.md`.

Expected: most tests pass. Edge cases noted in run plan.

On pass → review. On fail → fix and re-queue.
```

That's it. No stat tables, no §-citations, no internal skill names, no SHA dumps. The next agent reads the comment for *intent*, then opens the run plan for *detail*.

## What each agent does NOT do

| Agent | Forbidden |
|---|---|
| Coding agent | Run e2e tests inline. Touch `in-progress` on a PR (except briefly during merge). Modify other agents' claim labels. |
| E2E agent | Modify code. Touch `status:coding` (that's the coding agent's signal). Push commits. |
| Merge logic | Claim issues that aren't already `status:review-clean`. Bypass `merge.required_checks`. Override the `human-review` veto label. |

## Idempotency

All agents must be idempotent on tick re-runs:
- Coding agent claims are verified via the claim protocol's verify-after-add (`references/claim-protocol.md`); duplicate claims self-evict.
- E2E agent re-running on an issue already in `status:e2e-running` is a no-op (exits step 3 because the label is already taken; refresh stale recovery if applicable).
- Merge step is naturally idempotent — a second merge attempt on a closed issue exits at "issue not in `status:review-clean`."

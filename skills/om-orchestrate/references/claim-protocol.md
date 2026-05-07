# Claim protocol — race-safe issue claims

Replaces v0.1's incorrect "GitHub returns 422 on duplicate add-assignee" assumption. GitHub's REST API does not give us atomic CAS on assignees — they are additive. The corrected primitive uses a **single-instance claim label + verify-after-add + lowest-timestamp tiebreaker**.

## The primitive

```bash
# Claim issue $ISSUE for this agent.
# Returns 0 on win, 1 on race-loss (caller should exit silently).
claim_issue() {
  local issue=$1
  local me="agent-$(date +%s%N)-$$-$(hostname)"   # unique: timestamp-pid-host

  # 1. Read current claim labels (so we know what to remove later)
  local prior_my_claims=$(gh issue view "$issue" --json labels --jq \
    '.labels[].name | select(startswith("claim:agent-")) | select(test("'"$$"'-'"$(hostname)"'"))')

  # 2. Add our claim label (atomic per-call)
  gh issue edit "$issue" --add-label "claim:$me"

  # 3. Verify-after-add — re-fetch and find the winner (lowest timestamp wins)
  local winner=$(gh issue view "$issue" --json labels --jq \
    '.labels[].name | select(startswith("claim:agent-")) | sub("claim:";"")' | sort | head -1)

  if [[ "$winner" != "$me" ]]; then
    # Lost the race — self-evict
    gh issue edit "$issue" --remove-label "claim:$me"
    return 1
  fi

  # 4. We won — convert to status:coding and add assignee
  gh issue edit "$issue" \
    --remove-label "status:ready" \
    --add-label "status:coding" \
    --add-assignee "@me"

  # 5. Remove any prior stale claims from previous runs of this agent
  for stale in $prior_my_claims; do
    gh issue edit "$issue" --remove-label "$stale" 2>/dev/null || true
  done

  return 0
}
```

## Why this works

- Steps 1, 2, 3 are each one atomic GitHub API call.
- N agents racing on the same issue: all N add their `claim:agent-<ts>-<pid>-<host>` labels. All N read all N labels. All N agree on the same winner (deterministic — lowest unix-timestamp string wins). N-1 self-evict.
- Window between step 2 and step 3 is ~200ms in practice; race resolution is sub-second.
- Tiebreaker is deterministic across machines: timestamps are nanosecond-resolution unix epochs.

## Stale-claim recovery

If `claim:agent-*` is older than `recovery.stale_claim_minutes` (default 30 min) AND the issue lacks `status:coding` (i.e., the claimant crashed before completing step 4) — any subsequent claimant treats it as expired and removes it before claiming.

```bash
clean_stale_claims() {
  local issue=$1
  local now=$(date +%s)
  local threshold=$((now - STALE_CLAIM_MINUTES * 60))

  gh issue view "$issue" --json labels --jq '.labels[].name' | \
    grep "^claim:agent-" | while read claim; do
    # Extract the unix-nanosecond timestamp from the label
    local ts_ns=$(echo "$claim" | sed 's/claim:agent-\([0-9]*\)-.*/\1/')
    local ts=$((ts_ns / 1000000000))
    if [[ "$ts" -lt "$threshold" ]]; then
      # Verify the claimant didn't progress to status:coding before crashing
      if ! gh issue view "$issue" --json labels --jq '.labels[].name' | grep -q "^status:coding$"; then
        gh issue edit "$issue" --remove-label "$claim"
      fi
    fi
  done
}
```

This sweep runs at the start of every coding-agent tick before attempting a claim.

## Claim-PR vs claim-issue separation

The orchestration's claim is on the **issue**. The auto-* trio (`om-auto-create-pr`, `om-auto-continue-pr`, `om-auto-review-pr`) has its own claim protocol on the **PR** via the `in-progress` label. These are complementary:

- Issue's `claim:agent-*` and `status:coding` say "this issue is in active orchestration."
- PR's `in-progress` says "an auto-* skill is mid-flight on this PR; do not clobber."

A coding agent that claims an issue and then invokes `om-auto-create-pr` will see auto-create-pr's own claim happen on the PR. No contention — different label namespaces.

The merge step (in coding-agent Step 5) briefly applies `in-progress` to the PR before calling `gh pr merge`. This claims the merge action against any concurrent auto-skill. Released on merge success or failure.

## What never to use as a claim primitive

- `--add-assignee` alone — additive, not exclusive. Two agents can both add themselves.
- `gh issue lock` — meant for locking discussion threads, not claiming work. Repurposing it is gross and breaks the comment-based handoff.
- A single fixed label like `claim:taken` — destroys the lowest-timestamp tiebreaker; you'd race on add/remove of the same string.
- File-based locks in `/tmp` — defeats the "GitHub is the only state" invariant and breaks recovery from machine reboots.

## Test plan for the protocol

When implementing, write a smoke test:

1. Open a fake issue with `status:ready`.
2. Spawn two agents simultaneously (both try to claim).
3. Verify exactly one ends up with `status:coding` + `claim:agent-<X>` (no other claim labels).
4. Verify the loser is silent (no error log spam).
5. Repeat with N=5 agents.

If this passes, the claim primitive is good. If not, the design has a bug that won't surface until you actually go multi-agent in v1.13.0 — better to catch it now in v1.12.0 even though Phase 1 is single-agent.

# Dispatcher — `/om-orchestrate run`

The outer bash wrapper that spawns the e2e singleton + N coding agents and keeps the fleet sized until the queue drains. Lives in `scripts/dispatcher.sh` of this skill.

## Phase 1 (v1.12.0) behavior

Single-agent + singleton mode. `parallel_n=1` in `.ai/orchestration.yml`. The dispatcher:

1. Validates config and pre-flight (gh auth, labels exist, .ai/orchestration.yml present).
2. Reads the App Spec (or execution plan path) provided as argument.
3. **Opens issues** for any spec without an existing open issue.
4. **Spawns the e2e singleton** as a long-lived `claude -p` /loop process.
5. **Spawns one coding agent** as a per-tick fresh `claude -p` process.
6. After each tick (60s default), checks queue state. If work remains and no coding agent is alive, spawn one. Continue until queue drains.
7. When queue is empty for `idle_exit_ticks` consecutive ticks, kill the e2e singleton, write a final summary, exit.

Phase 2 raises `parallel_n` and the dispatcher keeps N in flight instead of one. Phase 3 adds failure-recovery sweeps in the dispatcher loop.

## Invariants

- **One e2e singleton process at a time.** Dispatcher refuses to spawn a second; if the running one is dead, spawn one fresh.
- **Coding agents are short-lived.** Each one runs one tick and exits. Dispatcher decides whether to spawn another.
- **No filesystem state required for correctness.** Dispatcher state is reconstructible from GitHub labels + the running PIDs of spawned processes.
- **The dispatcher itself is killable.** If it dies, re-running `/om-orchestrate run` resumes from labels — does not re-create issues, does not orphan running e2e/coding processes.

## Spawn commands

```bash
SKILL_ROOT="${OM_SKILL_ROOT:-$HOME/.claude/plugins/cache/om-superpowers/om-superpowers/<VERSION>/skills/om-orchestrate}"

# E2E singleton — one long-lived process
spawn_e2e_singleton() {
  if pgrep -f "om-agent-e2e" >/dev/null; then
    echo "E2E singleton already running."
    return
  fi
  nohup claude -p "/loop ${E2E_POLL_CADENCE_SECONDS}s $(cat $SKILL_ROOT/prompts/e2e-agent.md)" \
    --dangerously-skip-permissions \
    > "/tmp/om-agent-e2e.log" 2>&1 &
  echo $! > "/tmp/om-agent-e2e.pid"
}

# Coding agent — per-tick fresh
spawn_coding_agent() {
  local ts=$(date +%s)
  nohup claude -p "$(cat $SKILL_ROOT/prompts/coding-agent.md)" \
    --dangerously-skip-permissions \
    > "/tmp/om-agent-coding-${ts}.log" 2>&1 &
}
```

## Dispatcher main loop

```bash
#!/bin/bash
# scripts/dispatcher.sh — Phase 1 (v1.12.0)
set -euo pipefail

# 1. Pre-flight
source "$SKILL_ROOT/scripts/preflight.sh"
load_orchestration_yml ".ai/orchestration.yml"

# 2. Open issues for any spec lacking one
ensure_issues_for_specs "$APP_SPEC_PATH"

# 3. Spawn e2e singleton
spawn_e2e_singleton

# 4. Main loop
idle=0
while true; do
  # Open issue counts by status
  in_flight=$(gh issue list --label "status:coding" --state open --json number --jq 'length')
  ready=$(gh issue list --label "status:ready" --state open --json number --jq 'length')
  needs_resume=$(gh issue list --label "status:e2e-passed,status:e2e-failed" --state open --json number --jq 'length')
  active_total=$(gh issue list --label "status:backlog,status:ready,status:coding,status:needs-e2e,status:e2e-running,status:e2e-passed,status:e2e-failed,status:review" --state open --json number --jq 'length')

  # Dependency promotion: any status:backlog whose Blocked-by chain is satisfied → status:ready
  promote_unblocked_issues

  # Termination check
  if [[ "$active_total" -eq 0 ]]; then
    idle=$((idle + 1))
    if [[ "$idle" -ge "$IDLE_EXIT_TICKS" ]]; then
      kill_e2e_singleton
      write_summary
      echo "Queue drained. Exiting."
      exit 0
    fi
  else
    idle=0
  fi

  # Spawn coding agents up to parallel_n
  needed=$((PARALLEL_N - in_flight))
  if [[ "$needed" -gt 0 && $((ready + needs_resume)) -gt 0 ]]; then
    for i in $(seq 1 "$needed"); do
      spawn_coding_agent
    done
  fi

  sleep "$POLL_CADENCE_SECONDS"
done
```

## Functions referenced above

The dispatcher script ships with helpers (`scripts/preflight.sh`, etc.) for:

- `load_orchestration_yml` — reads YAML, exports env vars (uses `yq` if available; falls back to a Python parser shipped with the skill).
- `ensure_issues_for_specs` — for each spec in the input, opens an issue with the canonical title/body if one doesn't already exist (idempotent).
- `promote_unblocked_issues` — scans `status:backlog`, parses `Blocked by #N` lines, removes/replaces with `status:ready` when all blockers are closed.
- `kill_e2e_singleton` — graceful SIGTERM; if not dead in 5s, SIGKILL.
- `write_summary` — short final report posted as a comment on the App Spec issue (if one exists) or printed to stdout.

## Resuming after dispatcher crash

If the dispatcher itself dies (kill, machine restart), re-running `/om-orchestrate run` is the recovery path:

- `ensure_issues_for_specs` is idempotent (it skips specs that already have open issues).
- `spawn_e2e_singleton` checks if one is already running; skips if yes.
- Active coding agents that were spawned by the prior dispatcher are still running their ticks; they continue and exit normally.
- The new dispatcher main loop picks up where the old one left off.

No state migration needed — labels are the truth.

## Logs

- Each coding agent process: `/tmp/om-agent-coding-<timestamp>.log`
- E2E singleton: `/tmp/om-agent-e2e.log`
- Dispatcher itself: `/tmp/om-dispatcher.log`

User can `tail -f /tmp/om-agent-*.log` for real-time visibility. No log rotation in v1.12.0; user manages.

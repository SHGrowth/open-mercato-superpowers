#!/bin/bash
# om-orchestrate dispatcher — Phase 1 (v1.12.0)
#
# Spawns the e2e singleton + N coding agents, keeps the fleet sized
# until the queue drains. State of truth: GitHub labels. Stateless
# beyond labels and running PIDs.
#
# Phase 1 default: parallel_n=1 (single coding agent). Phase 2 raises
# this to spawn N concurrent coding agents.

set -euo pipefail

# ============================================================================
# Resolution of skill root and config paths
# ============================================================================

SKILL_ROOT="${OM_SKILL_ROOT:-}"
if [[ -z "$SKILL_ROOT" ]]; then
  # Try to detect from this script's location
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
  SKILL_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
fi

CONFIG_PATH="${OM_CONFIG_PATH:-.ai/orchestration.yml}"

# ============================================================================
# Pre-flight
# ============================================================================

preflight() {
  command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not found." >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found." >&2; exit 1; }

  gh auth status >/dev/null 2>&1 || { echo "ERROR: not logged in to gh. Run 'gh auth login'." >&2; exit 1; }

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not inside a git repo." >&2; exit 1; }

  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "ERROR: $CONFIG_PATH not found. Run '/om-orchestrate init' first." >&2
    exit 1
  fi

  # Check that all 11 status labels exist
  local needed_labels=(
    "status:backlog" "status:ready" "status:coding" "status:needs-e2e"
    "status:e2e-running" "status:e2e-passed" "status:e2e-failed"
    "status:review" "status:review-clean" "status:blocked" "human-review"
  )
  local existing_labels
  existing_labels=$(gh label list --limit 100 --json name --jq '.[].name' 2>/dev/null || true)
  for lbl in "${needed_labels[@]}"; do
    if ! echo "$existing_labels" | grep -qx "$lbl"; then
      echo "ERROR: Label '$lbl' missing. Run '/om-orchestrate init' to recreate." >&2
      exit 1
    fi
  done
}

# ============================================================================
# YAML → env vars
# ============================================================================

load_config() {
  # Prefer yq if available; fallback to a Python parser
  if command -v yq >/dev/null 2>&1; then
    export OM_E2E_COMMAND=$(yq -r '.e2e.command' "$CONFIG_PATH")
    export OM_E2E_REQUIRED_ENV=$(yq -r '.e2e.required_env | join(",")' "$CONFIG_PATH")
    export OM_E2E_TIMEOUT_MINUTES=$(yq -r '.e2e.timeout_minutes // 15' "$CONFIG_PATH")
    export OM_E2E_ALLOW_FAILURE_OUTPUT=$(yq -r '.e2e.allow_failure_output // false' "$CONFIG_PATH")
    export OM_MERGE_STRATEGY=$(yq -r '.merge.strategy // "squash"' "$CONFIG_PATH")
    export OM_MERGE_DELETE_BRANCH=$(yq -r '.merge.delete_branch // true' "$CONFIG_PATH")
    export OM_MERGE_BASE_BRANCH=$(yq -r '.merge.base_branch // "develop"' "$CONFIG_PATH")
    export OM_PARALLEL_N=$(yq -r '.orchestration.parallel_n // 1' "$CONFIG_PATH")
    export OM_POLL_CADENCE_SECONDS=$(yq -r '.orchestration.poll_cadence_seconds // 60' "$CONFIG_PATH")
    export OM_E2E_POLL_CADENCE_SECONDS=$(yq -r '.orchestration.e2e_poll_cadence_seconds // 30' "$CONFIG_PATH")
    export OM_IDLE_EXIT_TICKS=$(yq -r '.orchestration.idle_exit_ticks // 5' "$CONFIG_PATH")
    export OM_STALE_CLAIM_MINUTES=$(yq -r '.recovery.stale_claim_minutes // 30' "$CONFIG_PATH")
    export OM_STALE_E2E_MINUTES=$(yq -r '.recovery.stale_e2e_minutes // 20' "$CONFIG_PATH")
    export OM_TELEMETRY_LOG_DIR=$(yq -r '.telemetry.log_dir // "/tmp/om-telemetry"' "$CONFIG_PATH")
  else
    # Python fallback — parses YAML, exports vars
    eval "$(python3 -c "
import yaml, sys
with open('$CONFIG_PATH') as f:
    c = yaml.safe_load(f)
e = c.get('e2e', {})
m = c.get('merge', {})
o = c.get('orchestration', {})
r = c.get('recovery', {})
t = c.get('telemetry', {})
print(f'export OM_E2E_COMMAND=\"{e.get(\"command\", \"\")}\"')
print(f'export OM_E2E_REQUIRED_ENV=\"{\",\".join(e.get(\"required_env\", []))}\"')
print(f'export OM_E2E_TIMEOUT_MINUTES={e.get(\"timeout_minutes\", 15)}')
print(f'export OM_E2E_ALLOW_FAILURE_OUTPUT={str(e.get(\"allow_failure_output\", False)).lower()}')
print(f'export OM_MERGE_STRATEGY={m.get(\"strategy\", \"squash\")}')
print(f'export OM_MERGE_DELETE_BRANCH={str(m.get(\"delete_branch\", True)).lower()}')
print(f'export OM_MERGE_BASE_BRANCH={m.get(\"base_branch\", \"develop\")}')
print(f'export OM_PARALLEL_N={o.get(\"parallel_n\", 1)}')
print(f'export OM_POLL_CADENCE_SECONDS={o.get(\"poll_cadence_seconds\", 60)}')
print(f'export OM_E2E_POLL_CADENCE_SECONDS={o.get(\"e2e_poll_cadence_seconds\", 30)}')
print(f'export OM_IDLE_EXIT_TICKS={o.get(\"idle_exit_ticks\", 5)}')
print(f'export OM_STALE_CLAIM_MINUTES={r.get(\"stale_claim_minutes\", 30)}')
print(f'export OM_STALE_E2E_MINUTES={r.get(\"stale_e2e_minutes\", 20)}')
print(f'export OM_TELEMETRY_LOG_DIR={t.get(\"log_dir\", \"/tmp/om-telemetry\")}')
")"
  fi

  # Sanity-check the critical fields
  [[ -z "$OM_E2E_COMMAND" ]] && { echo "ERROR: e2e.command is empty in $CONFIG_PATH." >&2; exit 1; }
  [[ "$OM_PARALLEL_N" -lt 1 ]] && OM_PARALLEL_N=1
  [[ "$OM_PARALLEL_N" -gt 20 ]] && { echo "WARN: parallel_n=$OM_PARALLEL_N capped to 20." >&2; OM_PARALLEL_N=20; }

  mkdir -p "$OM_TELEMETRY_LOG_DIR"

  export OM_SKILL_ROOT="$SKILL_ROOT"
}

# ============================================================================
# Spawning
# ============================================================================

spawn_e2e_singleton() {
  if pgrep -f "om-agent-e2e-singleton" >/dev/null 2>&1; then
    echo "E2E singleton already running."
    return
  fi

  local prompt_path="$SKILL_ROOT/prompts/e2e-agent.md"
  [[ ! -f "$prompt_path" ]] && { echo "ERROR: $prompt_path missing." >&2; exit 1; }

  # Tag the process via env so pgrep can find it
  OM_AGENT_TAG="om-agent-e2e-singleton" \
    nohup claude -p "/loop ${OM_E2E_POLL_CADENCE_SECONDS}s $(cat "$prompt_path")" \
      --dangerously-skip-permissions \
      > "/tmp/om-agent-e2e.log" 2>&1 &
  echo $! > "/tmp/om-agent-e2e.pid"
  echo "E2E singleton spawned (pid $!)."
}

spawn_coding_agent() {
  local ts
  ts=$(date +%s)

  local prompt_path="$SKILL_ROOT/prompts/coding-agent.md"
  [[ ! -f "$prompt_path" ]] && { echo "ERROR: $prompt_path missing." >&2; exit 1; }

  OM_AGENT_TAG="om-agent-coding-${ts}" \
    nohup claude -p "$(cat "$prompt_path")" \
      --dangerously-skip-permissions \
      > "/tmp/om-agent-coding-${ts}.log" 2>&1 &
}

# ============================================================================
# Issue management
# ============================================================================

ensure_issues_for_specs() {
  local app_spec_path="$1"
  if [[ ! -f "$app_spec_path" ]]; then
    echo "WARN: app spec '$app_spec_path' not found. Skipping auto-issue creation. Existing issues will be processed." >&2
    return
  fi

  # Phase 1 simplification: do not auto-decompose the App Spec.
  # The user is expected to run om-cto to decompose first, and that
  # workflow opens issues per spec. Phase 1 dispatcher trusts that
  # issues already exist for the specs to process.
  #
  # Future Phase: read the App Spec / EXECUTION-PLAN, find specs without
  # corresponding issues, open them with the canonical title/body.

  echo "ensure_issues_for_specs: trusting existing issues. Open issues with status labels:"
  gh issue list --label "status:backlog,status:ready,status:coding" --state open --json number,title --jq '.[] | "  #\(.number): \(.title)"'
}

promote_unblocked_issues() {
  # For each status:backlog, check if Blocked-by chain is satisfied.
  # If yes, transition to status:ready.
  local backlog_issues
  backlog_issues=$(gh issue list --label "status:backlog" --state open --json number --jq '.[].number')

  for issue in $backlog_issues; do
    local body
    body=$(gh issue view "$issue" --json body --jq '.body')
    local blockers
    blockers=$(echo "$body" | grep -oE 'Blocked by #[0-9]+' | grep -oE '[0-9]+' | sort -u)

    local all_closed=true
    for blocker in $blockers; do
      local state
      state=$(gh issue view "$blocker" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
      if [[ "$state" != "CLOSED" ]]; then
        all_closed=false
        break
      fi
    done

    if [[ "$all_closed" == "true" ]]; then
      gh issue edit "$issue" --remove-label "status:backlog" --add-label "status:ready" 2>/dev/null && \
        echo "Promoted #$issue from backlog to ready."
    fi
  done
}

# ============================================================================
# Cleanup
# ============================================================================

kill_e2e_singleton() {
  if [[ -f "/tmp/om-agent-e2e.pid" ]]; then
    local pid
    pid=$(cat "/tmp/om-agent-e2e.pid")
    kill "$pid" 2>/dev/null || true
    sleep 5
    kill -9 "$pid" 2>/dev/null || true
    rm -f "/tmp/om-agent-e2e.pid"
  fi
}

write_summary() {
  local closed
  closed=$(gh issue list --label "status:coding,status:review,status:review-clean" --state closed --json number,title --jq 'length')
  local blocked
  blocked=$(gh issue list --label "status:blocked" --state open --json number --jq 'length')

  echo ""
  echo "=== Orchestration summary ==="
  echo "Closed (merged): $closed"
  echo "Blocked: $blocked"
  echo "Logs: /tmp/om-agent-*.log"
  echo "Telemetry: $OM_TELEMETRY_LOG_DIR"
  echo "============================="
}

# ============================================================================
# Main loop
# ============================================================================

main() {
  preflight
  load_config

  echo "om-orchestrate dispatcher starting."
  echo "  Config: $CONFIG_PATH"
  echo "  Parallel N: $OM_PARALLEL_N"
  echo "  E2E command: $OM_E2E_COMMAND"
  echo "  Base branch: $OM_MERGE_BASE_BRANCH"
  echo "  Logs: /tmp/om-agent-*.log"

  trap 'kill_e2e_singleton; write_summary; exit 0' INT TERM

  local app_spec_path="${1:-app-spec/app-spec.md}"
  ensure_issues_for_specs "$app_spec_path"

  spawn_e2e_singleton

  local idle=0
  while true; do
    promote_unblocked_issues

    local in_flight ready needs_resume active_total
    in_flight=$(gh issue list --label "status:coding" --state open --json number --jq 'length')
    ready=$(gh issue list --label "status:ready" --state open --json number --jq 'length')
    needs_resume=$(gh issue list --label "status:e2e-passed,status:e2e-failed,status:review-clean" --state open --json number --jq 'length')
    active_total=$(gh issue list --label "status:backlog,status:ready,status:coding,status:needs-e2e,status:e2e-running,status:e2e-passed,status:e2e-failed,status:review,status:review-clean" --state open --json number --jq 'length')

    if [[ "$active_total" -eq 0 ]]; then
      idle=$((idle + 1))
      echo "Idle tick $idle/$OM_IDLE_EXIT_TICKS (no active issues)."
      if [[ "$idle" -ge "$OM_IDLE_EXIT_TICKS" ]]; then
        kill_e2e_singleton
        write_summary
        echo "Queue drained. Exiting."
        exit 0
      fi
    else
      idle=0
    fi

    local needed=$((OM_PARALLEL_N - in_flight))
    if [[ "$needed" -gt 0 && $((ready + needs_resume)) -gt 0 ]]; then
      for i in $(seq 1 "$needed"); do
        spawn_coding_agent
        echo "Spawned coding agent #$i."
      done
    fi

    sleep "$OM_POLL_CADENCE_SECONDS"
  done
}

main "$@"

# Implementation Orchestrator Mode

When the user approves the specs and execution plan, Piotr coordinates implementation. Autonomous per-spec with user checkpoint between specs.

## Per-spec loop

For each spec in execution plan order:

### Step 1 — Dispatch implementation

Invoke the base `implement-spec` skill (or `auto-create-pr` for PR-based delivery) with:
- The functional spec file path
- The dispatch context below

The implementation skill will auto-invoke domain skills as needed:
- `module-scaffold` (new module creation)
- `data-model-design` (entity work)
- `system-extension` (UMES extensions)
- `backend-ui-design` (UI pages)
- `troubleshooter` (if verification fails)
- `code-review` (auto-chain after verification)
- `integration-tests` (write AND run)

### Step 2 — Verify completion

Confirm the implementation completed the full pipeline:
- Implementation done
- Unit tests: written and passing
- Integration tests: written, executed, and passing
- **Code review: `om-auto-review-pr <PR#>` invoked against the resulting PR and returned a clean verdict** (autofix loop applied, all Critical/High findings fixed, DS-Guardian REVIEW chained for any UI changes). Self-review against the checklist by the implementer is not a substitute. As of v1.11.6, `om-implement-spec` Step 9 enforces this; Piotr verifies it actually ran and passed before checkpointing.
- Spec updated with implementation status

If implementation reports blockers, Piotr diagnoses and resolves them before proceeding.

### Step 3 — Checkpoint with user

> "Spec N/M done: {Feature Name}.
> - Tests: X/X green
> - Code review: passed
> - Feature is live on localhost:3000
>
> Please test the feature. When ready:
> - **'next'** → I proceed to Spec N+1
> - **Any feedback** → I triage it (code bug / spec gap / business change) and handle accordingly"

### Step 3.5 — Proxy pre-triage

Before presenting feedback triage to the user, consult `references/user-proxy.md` (the proxy reference) with the findings. The proxy can resolve:
- **Code bugs** — always fixable without user input (proxy resolves: "fix it")
- **Spec gaps** where the answer is in the app spec — proxy resolves with citation

The proxy escalates:
- **Business changes** — always needs user judgment
- **Spec gaps** where the answer is NOT in the app spec or lessons

### Step 4 — Triage user feedback

Every piece of user feedback (bug report, change request, observation) MUST be triaged before acting. The feedback may indicate a code bug, a spec gap, or a business requirement change — each requires a different response.

**Triage process:**

1. **Piotr classifies** the feedback into one of three levels:

| Level | Meaning | Example | Action |
|---|---|---|---|
| **Code bug** | Implementation doesn't match the spec | "Button doesn't save" / "Wrong API response" | Fix code, re-verify, re-checkpoint. No spec changes. |
| **Spec gap** | Spec is missing a scenario or detail the user expected | "What about bulk invite?" / "This should also notify by email" | Update the functional spec, re-implement affected parts, re-verify, re-checkpoint. |
| **Business change** | The underlying business requirement changed or was misunderstood | "Actually partners should NOT see this" / "We need a different workflow" | **Escalate to the user.** Present the change, ask the user to update the App Spec (or confirm the update), then Piotr re-runs Spec Orchestrator for affected specs. |

2. **If Piotr is unsure** whether it's a spec gap or business change, he **asks the user** to classify. Present both interpretations and let the user decide.

> **No autonomous re-dispatch to om-product-manager.** Business changes surface to the user, who decides whether to re-engage Cagan for a full App Spec revision or handle it as a scoped update. This prevents circular om-cto ↔ om-product-manager loops.

3. **After triage:**
   - Code bug → Piotr fixes autonomously
   - Spec gap → Piotr updates the functional spec, then re-implements
   - Business change → User confirms App Spec update → Piotr re-runs spec writing for affected specs → user re-reviews → Piotr re-implements

This ensures the App Spec and functional specs stay in sync with reality. Specs are living documents, not throwaway artifacts.

## After all specs complete

> "All N specs implemented and tested.
> - Total tests: X green
> - All code reviews: passed
>
> Ready to commit/push the full feature set, or would you like to review anything?"

---

## Dispatch Context: Implementation

When dispatching the base `implement-spec` skill from this orchestrator, pass this context:

- **Pipeline lock:** The full pipeline MUST be followed — Plan → Implement → Unit Tests → Integration Tests (run them!) → Docs → Self-Review → Update Spec → Verification → Code Review → Commit. No steps skipped. No early exit.
- **Subagent mode:** Technical decisions are in the spec's `## Technical Approach` section. Do NOT ask Extension Mode Decision — Piotr already decided.
- **Proxy gate:** For standalone extension-vs-core decisions, consult `references/user-proxy.md` (the proxy reference) before asking the user.

## Autonomous loop policy

Implementation runs **in this conversation, chained**. If the user asks for unattended/Ralph-style execution, use one of:

- `/loop 5m /auto-continue-pr <PR#>` — harness cron mode, fresh context per turn, 5-minute interval. The right tool for unattended Ralph runs.
- A single long Task agent (e.g., `om-auto-create-pr` / `om-auto-continue-pr`) that runs the run-plan checklist end-to-end without exiting between iterations.

**Never** use `/loop` *self-paced* (no interval) for chained autonomous coding. Self-pace makes the agent call `ScheduleWakeup` between iterations, whose documented default for idle ticks is **1200–1800 s**. With queued work this inserts a 20–30 min do-nothing gap per commit and the agent will invent a cache-warmth rationale that contradicts the 5-min cache TTL. Self-pace is calibrated for *polling external signals* (a build, a PR queue), not for chained spec implementation. See `docs/specs/2026-05-07-autonomous-loop-policy.md` for the patryk forensic that drove this rule.

## Dispatch Context: Code Review

When dispatching the base `code-review` skill from this orchestrator, pass this context:

- **CI/CD verification gate (MANDATORY):** Run the same checks CI runs — typecheck, unit tests, i18n, build. Every gate MUST pass before the review can conclude.
- **Template parity gate:** Run `yarn template:sync`. If drift is reported, consult `references/user-proxy.md` (the proxy reference) before asking the user. The proxy resolves "yes, sync" if the drift is in files the current changes touch.
- **Backward compatibility gate:** Check every change against `BACKWARD_COMPATIBILITY.md`. Flag any violation as Critical.
- **Proxy gate:** Before presenting findings to user, run through `references/user-proxy.md`.

# om-implement-spec Post-PR Review Gate — close the "PR opened ≠ done" gap

**Date:** 2026-05-07
**Status:** Shipped — v1.11.6
**Owner:** Mat (CEO)
**Triggered by:** PRM PR #4 + PR #5 — same shape, same gap, two consecutive incidents

## What happened

Two consecutive autonomous PRM spec implementations stopped at "PR opened" without invoking any real code-review pass on the resulting PR.

**PR #4 (Spec #4 — WIC ingestion):** the agent posted a "merge-ready" comment, then the user asked at 22:07: *"we havent closed this in clean way, have we run tests, ui tests, design system review code review?"* That correction triggered 5 cleanup iterations (the same Iter 1–5 that v1.11.5's forensic also references, but for a different reason — that was the /loop self-pace problem).

**PR #5 (Spec #5 — RFP broadcast/response):** the agent landed 14 commits in one chained conversation (correctly, per v1.11.5), shipped C5 ("Run full gate: typecheck, jest, integration. Open PR. Done."), opened PR #5 against `develop`, posted a closing message *"Spec #5 shipped end-to-end as PR #5"*, and went idle. **No `om-auto-review-pr` invocation. No `om-ds-guardian REVIEW` on the new portal pages (P9, P10). No security checklist pass on the new portal routes. No execution of Playwright §9.2–§9.5.**

When the user asked: *"why it stopped before reviewing the design, tests, e2e ui tests, code review?"* — the answer was the same gap as PR #4. The fix from PR #4 was never encoded into om-superpowers; it lived only in the user's session memory.

## What's wrong with this

The implementer's "definition of done" stops one step too early. Compare the three skills that produce/touch a PR:

| Skill | Has explicit `om-auto-review-pr` invocation step? |
|---|---|
| `om-auto-create-pr` | ✅ Step 11 — runs auto-review-pr in autofix loop until clean |
| `om-auto-continue-pr` | ✅ Step 7 — same pattern |
| `om-implement-spec` | ❌ — Step 6 is "Self-Review" (agent reads checklist to itself); Step 8 is build/lint/tests but not auto-review-pr; ends after Step 8 |

`om-implement-spec`'s Step 6 ("Self-Review (Code-Review Gate)") is the implementer reading the checklist to itself. That catches roughly the rules the implementer was already trying to follow. It does NOT catch:

- Cross-file architectural concerns (only visible in PR diff context)
- Security checklist items that need fresh eyes (orgId scoping, tenant isolation, ACL guards on every new route)
- DS-Guardian findings on UI changes (status pill misuse, raw HTML controls, hardcoded colors, missing empty/loading states)
- BC concerns on contract surfaces (event ID changes, public export shape changes, migration ordering)
- Test-coverage gates that fire on the *commit boundary*, not per-file

The orchestrator (`impl-orchestrator.md` Step 2) names "Code review: passed" as a gate, but does not actually invoke `om-auto-review-pr` — it leaves that to the implementer, which doesn't do it.

Net cost: every spec implementation produces a PR that *looks* complete but bypasses the same review pass every other PR-producing skill enforces. The gap surfaces only when the user manually asks for review (PR #4) or notices the cleanup didn't happen (PR #5).

## Root cause

`om-implement-spec` evolved from a "write code from a spec" skill, before `om-auto-review-pr` was wired in as the standard PR-level gate. When `om-auto-review-pr` and the autofix loop were added (and `om-auto-create-pr` / `om-auto-continue-pr` got Step 11/7 to invoke them), `om-implement-spec` wasn't updated to match. The implementer's "Verification" step (Step 8) runs CI-equivalent checks (typecheck/lint/tests/build) but does NOT chain into the review skill.

## Fix shape (v1.11.6)

Three doc layers, no enforcement code (same shape as v1.11.5):

1. **`skills/om-implement-spec/SKILL.md` — new Step 9 "Post-PR Review Gate (mandatory when a PR was opened)".** Mirrors the language from `om-auto-create-pr` Step 11 and `om-auto-continue-pr` Step 7. Explicit autofix loop, explicit chaining to `om-ds-guardian REVIEW` for UI work, explicit non-actionable-finding documentation requirement.

2. **`skills/om-cto/references/impl-orchestrator.md` Step 2 — operationalize the "Code review: passed" bullet.** Was a passive checkbox the implementer self-attested. Now explicitly says `om-auto-review-pr <PR#>` must be invoked and return a clean verdict. Piotr verifies it actually ran.

3. **`om-implement-spec` Rules block — one-liner.** "MUST NOT report a spec implementation complete until `om-auto-review-pr` has returned a clean verdict on the resulting PR (Step 9). Step 6's self-review is not a substitute."

Plus a feedback memory in the user's auto-memory store so future sessions in om-superpowers context don't re-derive the rule.

## Why doc-only, no hook

A `PreToolUse` hook that intercepts the implementer's "report complete" pathway and verifies a recent `om-auto-review-pr` clean verdict on the relevant PR *would* enforce this mechanically. Rejected for v1.11.6 for the same reasons v1.11.5 rejected its hook:

- The trigger condition ("the implementer is about to report complete") doesn't have a single observable signal — it's spread across text outputs, TaskUpdate calls, run plan checkbox writes.
- Detecting "the relevant PR" requires parsing the run plan or the most recent commit message for a `gh pr create` invocation.
- False positives (legitimate "stopped early because user interrupted" or "stopped because real blocker" cases) would block valid escalations.
- The cost of two bad runs (PR #4 + PR #5) is recoverable. The cost of a flaky enforcement hook is annoying every implementation.

If the policy keeps getting violated despite v1.11.6, revisit and add the hook. Layer-1 (docs) gets a fair trial first. Same escalation ladder as v1.11.5.

## Verification — how we'd know this fix is working

- Future autonomous spec implementations show an `om-auto-review-pr <PR#>` invocation in the session jsonl AFTER `gh pr create` and BEFORE the final closing message.
- Spec implementations that opened a PR but skipped review don't reach the "X shipped end-to-end" closing summary; they either complete the gate or leave the spec in `in_progress` with a documented blocker.
- Future user audit prompts of the form *"have we run tests / DS / code review?"* against a freshly-shipped spec PR find that all three already ran.

## Cross-link to v1.11.5

v1.11.5 fixed *when* the implementer iterates (no /loop self-pace ScheduleWakeup gaps). v1.11.6 fixes *what counts as done* (real review pass, not self-review attestation). Together they close the two failure modes observed in the patryk-standalone forensic: wasted sleep between iterations (v1.11.5) AND premature "done" without review (v1.11.6). Same fix shape, same escalation ladder, same memory-and-doc layering. If a v1.11.7 emerges from the same forensic vein, it will likely be a hook escalation when the doc layer alone proves insufficient.

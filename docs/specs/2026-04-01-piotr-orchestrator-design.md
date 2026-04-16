# Piotr Orchestrator: Autonomous Technical Workflow

**Date:** 2026-04-01
**Status:** Implemented

## TLDR

Redesign om-cto (Piotr) from an interactive advisory skill into an autonomous orchestrator that coordinates the full technical lifecycle after the product manager (Cagan) finishes business discovery with the user. User only intervenes at 3 checkpoints: brainstorming with Cagan, reviewing specs, and testing features on localhost.

## Problem

Current OM superpowers are heavily human-in-the-loop for technical decisions. The agent asks the user questions it should answer itself:

- "Extension or Core?" — om-cto Phase 3+4 logic answers this
- "Plan OK?" per implementation phase — the spec already defines the plan
- "Should I run code review?" — always yes
- "Which UMES mechanism?" — om-system-extension decision tree answers this
- "New module or extend existing?" — om-cto minimal solution ladder answers this

Evidence from Session 1 (2026-04-01): user had to say "follow om superpowers" twice, "always code review" once, and "have you run them?" once — all re-steering the agent through steps that should be automatic.

## Design

### Lifecycle Overview

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: BUSINESS DISCOVERY (Cagan ↔ User)            │
│ Interactive brainstorming                            │
│ Output: App Spec (workflows, stories, criteria)      │
└──────────────────────┬──────────────────────────────┘
                       ↓ Cagan hands off to Piotr
┌─────────────────────────────────────────────────────┐
│ Phase 2: SPEC ORCHESTRATOR (Piotr, autonomous)      │
│ Decompose → Write specs → Cross-validate → Plan     │
│ Output: N functional specs + execution plan          │
└──────────────────────┬──────────────────────────────┘
                       ↓ CHECKPOINT
┌─────────────────────────────────────────────────────┐
│ User reviews specs + execution plan                  │
│ Can: approve, request changes, reorder               │
└──────────────────────┬──────────────────────────────┘
                       ↓ User approves
┌─────────────────────────────────────────────────────┐
│ Phase 3: IMPLEMENTATION ORCHESTRATOR (Piotr)         │
│ For each spec:                                       │
│   implement → test → review → CHECKPOINT (user test) │
└─────────────────────────────────────────────────────┘
```

### User Touchpoints (only 3)

| # | Checkpoint | Why human needed |
|---|---|---|
| 1 | Cagan brainstorming | Business requirements need human judgment |
| 2 | Review specs + execution plan | Final say on what gets built |
| 3 | Test each feature on localhost | Real-world validation between specs |

Everything else is autonomous.

### Piotr's Three Modes

| Mode | Trigger | User interaction | Output |
|---|---|---|---|
| **Advisory** (existing) | "does OM do X?", gap check, PR review | Interactive Q&A | Findings report |
| **Spec Orchestrator** | Receives App Spec from Cagan | Autonomous until specs ready | N specs + execution plan |
| **Implementation Orchestrator** | User approves specs + plan | Autonomous per-spec, checkpoint between | Working features |

Mode auto-detection:
- Cagan completes App Spec and hands off → **Spec Orchestrator**
- User approves specs and says "build" / "implement" → **Implementation Orchestrator**
- Everything else → **Advisory** (current behavior, unchanged)

### Phase 2: Spec Orchestrator (Detail)

When Piotr receives an App Spec from Cagan:

**Step 1 — Decompose.** Read App Spec, identify independent deliverable features. Each becomes one spec. Order by dependencies (foundation first, features that depend on others later).

**Step 2 — Write specs.** For each feature, dispatch coordinated subagents:

| Subagent | Skill | Purpose |
|---|---|---|
| Gap analyst | om-cto (advisory) | What exists in OM? What's the gap? Extension vs core? |
| Spec writer | om-spec-writing | Produce SPEC-YYYY-MM-DD-{slug}.md |
| Validator | om-pre-implement-spec | Check BC violations, risks, gaps |
| Data architect | om-data-model-design | Validate entity design (if applicable) |
| Extension architect | om-system-extension | Pick UMES mechanism (if applicable) |

Each spec writer subagent receives:
- The relevant App Spec section (workflow + user stories + success criteria)
- Piotr's gap analysis findings (what exists, what to build, HOW to build it)
- OM platform constraints from om-reference/

The spec writer does NOT brainstorm with the user — it has all the input it needs from Cagan's App Spec and Piotr's gap analysis.

**Step 3 — Cross-validate.** After all specs are written:
- Check for contradictions (same entity defined differently in two specs)
- Check for coverage gaps (App Spec user story not addressed by any spec)
- Check for circular dependencies between specs
- Verify execution ordering is valid (no spec depends on unbuilt spec)

**Step 4 — Execution plan.** Produce an ordered implementation schedule:

```markdown
## Execution Plan

| # | Spec | Depends on | Key technical decisions | Complexity |
|---|------|-----------|------------------------|------------|
| 1 | SPEC-2026-04-01-user-roles | — | New module, 3 entities | Medium |
| 2 | SPEC-2026-04-01-partnerships | #1 | UMES extension of customers | High |
| 3 | SPEC-2026-04-01-onboarding | #1, #2 | Widget injection + enricher | Medium |
```

Each row shows WHAT Piotr decided technically and WHY, so the user can review the approach.

**Step 5 — Present to user.** Single checkpoint:

> "Here are N specs and the execution plan. Each spec includes the technical approach I chose.
> Review them and let me know:
> - Approve all → I start building
> - Change spec X → I revise and re-validate
> - Reorder → I adjust dependencies"

### Phase 3: Implementation Orchestrator (Detail)

When user approves specs + plan:

**For each spec in execution order:**

**Step 1 — Implement.** Dispatch om-implement-spec as a subagent with:
- The functional spec file
- Piotr's technical decisions (already embedded in the spec from Phase 2)
- No Extension Mode Decision prompt — Piotr already decided
- Pipeline Lock active: implement → unit tests → integration tests → docs → self-review → verification → code review

om-implement-spec auto-invokes skill handoffs as needed:
- om-module-scaffold (new module)
- om-data-model-design (entities)
- om-system-extension (UMES extensions)
- om-troubleshooter (if verification fails)
- om-code-review (auto-chain after verification)

**Step 2 — Verify.** Automated gate:
- Unit tests: run, must pass
- Integration tests: run, must pass
- Code review: auto-invoke, fix Critical/High findings
- If anything fails: om-troubleshooter → fix → re-verify

**Step 3 — Checkpoint.** Report to user:

> "Spec 2/5 done: Partnership Settings.
> - Tests: 18/18 green
> - Code review: passed (2 Low findings, accepted)
> - Feature is live on localhost:3000
>
> Please test the feature. When ready, say 'next' to proceed to Spec 3."

**Step 4 — User responds:**
- "next" / "continue" → proceed to next spec
- Reports a bug → Piotr diagnoses using om-troubleshooter + om-cto, fixes, re-runs Step 2, re-checkpoints
- Requests a change → Piotr updates the spec, re-implements affected parts, re-checkpoints

### What Changes in Existing Skills

| Skill | Change | Details |
|---|---|---|
| **om-cto** | Add 2 new modes | Spec Orchestrator + Implementation Orchestrator sections. Advisory mode unchanged. Mode auto-detection in preamble. |
| **om-product-manager** | Explicit handoff | After App Spec complete: "Dispatch Piotr in Spec Orchestrator mode with the App Spec." Replace vague "piotr → brainstorming → planning" flow. |
| **om-implement-spec** | Subagent mode | When invoked by Piotr (spec has technical decisions embedded), skip Extension Mode Decision. Read approach from spec. Keep Pipeline Lock + all auto-chains. |
| **om-spec-writing** | Subagent mode | When dispatched by Piotr, use App Spec section + gap analysis as input instead of interactive user brainstorming. |
| **om-pre-implement-spec** | No change | Already works as autonomous analysis. Just gets auto-dispatched by Piotr. |
| **om-code-review** | No change | Already auto-chained from om-implement-spec. |
| **om-integration-tests** | No change | Already invoked by om-implement-spec Step 4. |

### What Becomes Autonomous

| Currently asks user | Now decided by |
|---|---|
| "Extension or Core?" | Piotr Phase 3+4 minimal solution ladder |
| "Plan OK?" per implementation phase | Spec already defines the plan |
| "Should I run code review?" | Pipeline Lock — always yes |
| "Should I run tests?" | Pipeline Lock — always yes |
| "Which UMES mechanism?" | om-system-extension decision tree |
| "New module or extend existing?" | Piotr Phase 4 |
| "Should I fix this test failure?" | om-troubleshooter — always yes |
| "What entity types/fields?" | om-data-model-design + spec definitions |

### What Stays Human

| Decision | Why |
|---|---|
| Business requirements (Cagan ↔ User) | Only the user knows what the business needs |
| Approve specs + execution plan | User owns what gets built |
| Test features on localhost | Real-world validation agents can't do |
| Report bugs during testing | User sees what the agent can't |
| Security escalation decisions | "Should we report upstream?" needs judgment |

## Risks

| Risk | Mitigation |
|---|---|
| Piotr makes wrong technical call | Specs are reviewed by user before implementation. User can override any technical decision. |
| Specs drift from App Spec intent | Cross-validation step catches coverage gaps. User review is the final gate. |
| Implementation breaks between specs | Each spec verified independently. User tests between specs. |
| Agent context window overflow | Piotr dispatches subagents — each works in bounded context. Cross-validation is a separate focused pass. |
| User wants more control on specific spec | Advisory mode still available. User can say "let me decide on this one." |

## Non-Goals

- Changing Cagan's interactive brainstorming flow — that stays human-in-the-loop
- Removing the ability to use skills individually — advisory mode and standalone invocation unchanged
- Full autopilot with zero checkpoints — user always reviews specs and tests features

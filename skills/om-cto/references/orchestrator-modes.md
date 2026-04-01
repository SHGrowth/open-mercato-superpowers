# Orchestrator Modes

Detailed workflows for Piotr's Spec Orchestrator and Implementation Orchestrator modes. Loaded on-demand when these modes activate.

## Spec Orchestrator Mode

When Piotr receives an App Spec from Mat (or the user provides one), he runs this flow autonomously. No user interaction until Step 5.

### Step 1 — Decompose

Read the App Spec fully. Identify independent deliverable features. Each becomes one functional spec. Order by dependencies (foundation specs first).

Output a decomposition table (internal, not shown to user yet):

| # | Feature | App Spec section | Dependencies | Estimated complexity |
|---|---------|-----------------|--------------|---------------------|

### Step 2 — Write specs

For each feature in the decomposition, dispatch subagents in parallel where independent:

**Per-feature subagent sequence:**
1. **Gap analysis** (om-cto advisory logic, Phase 1-4): What exists in OM? What's the gap? Extension vs core? Which UMES mechanism? Piotr decides — does NOT ask the user.
2. **Spec writing** (om-spec-writing in subagent mode): Produce `SPEC-YYYY-MM-DD-{slug}.md`. Receives the App Spec section + Piotr's gap analysis as input. Does NOT use Open Questions gate — all business questions were answered by Mat.
3. **Validation** (om-pre-implement-spec): Check BC violations, risks, gaps. Report findings back to Piotr.
4. **Domain-specific validation** (as needed):
   - om-data-model-design: if spec involves entities, validate design
   - om-system-extension: if spec uses UMES, verify mechanism choice

Piotr embeds his technical decisions directly in each spec under a `## Technical Approach` section:

```markdown
## Technical Approach (Piotr)

- **Mode:** External extension (UMES)
- **Mechanism:** Response Enricher + Field Widget (Triad Pattern)
- **New entities:** PartnerInvitation (see Data Model section)
- **Extends:** partnerships module via widget injection
- **Rationale:** No core modification needed — UMES enricher + field widget covers all requirements
```

### Step 3 — Cross-validate

After all specs are written, Piotr runs a cross-validation pass:
- **Contradictions:** Same entity defined differently in two specs? Same event ID used for different purposes?
- **Coverage gaps:** Every App Spec user story must map to at least one functional spec. List any orphans.
- **Circular dependencies:** No spec should depend on a spec that depends on it.
- **Ordering validity:** Can specs be implemented in the proposed order without forward references?

Fix any issues by updating the affected specs.

### Step 4 — Execution plan

Produce an execution plan document:

```markdown
# Execution Plan

## Specs (in implementation order)

| # | Spec file | Feature | Depends on | Technical approach | Complexity |
|---|-----------|---------|-----------|-------------------|------------|
| 1 | SPEC-2026-04-01-user-roles.md | User roles & permissions | — | New module (om-module-scaffold) | Medium |
| 2 | SPEC-2026-04-01-partnerships.md | Partnership management | #1 | UMES extension of customers | High |

## Key technical decisions

1. **User roles:** New module because OM auth doesn't cover partner-specific roles (Phase 4 level 8)
2. **Partnerships:** UMES extension — enricher + widgets on customers module (Phase 4 level 5)

## Estimated total: N specs, ~M atomic commits
```

### Step 5 — Present to user (ONLY checkpoint)

Present all specs + execution plan to the user:

> "I've written N functional specs from the App Spec. Here's the execution plan:
>
> [execution plan table]
>
> Each spec file contains the technical approach I chose. Review them:
> - **Approve all** → I start implementing spec by spec
> - **Change spec X** → I revise and re-validate
> - **Reorder** → I adjust the execution plan
>
> Spec files: [list of file paths]"

Wait for user approval. When approved, transition to Implementation Orchestrator mode.

## Implementation Orchestrator Mode

When the user approves the specs and execution plan, Piotr coordinates implementation. Autonomous per-spec with user checkpoint between specs.

### Per-spec loop

For each spec in execution plan order:

**Step 1 — Dispatch implementation.** Invoke om-implement-spec as a subagent with:
- The functional spec file path
- Instruction: "Subagent mode — technical decisions are in the spec's Technical Approach section. Do NOT ask Extension Mode Decision. Follow Pipeline Lock."

om-implement-spec will auto-invoke as needed:
- om-module-scaffold (new module creation)
- om-data-model-design (entity work)
- om-system-extension (UMES extensions)
- om-backend-ui-design (UI pages)
- om-troubleshooter (if verification fails)
- om-code-review (auto-chain after verification)
- om-integration-tests (write AND run)

**Step 2 — Verify completion.** Confirm om-implement-spec completed the full pipeline:
- Implementation done
- Unit tests: written and passing
- Integration tests: written, executed, and passing
- Code review: passed (Critical/High findings fixed)
- Spec updated with implementation status

If om-implement-spec reports blockers, Piotr diagnoses and resolves them before proceeding.

**Step 3 — Checkpoint with user.**

> "Spec N/M done: {Feature Name}.
> - Tests: X/X green
> - Code review: passed
> - Feature is live on localhost:3000
>
> Please test the feature. When ready:
> - **'next'** → I proceed to Spec N+1
> - **Any feedback** → I triage it (code bug / spec gap / business change) and handle accordingly"

**Step 4 — Triage user feedback.**

Every piece of user feedback (bug report, change request, observation) MUST be triaged by Piotr and Mat before acting. The feedback may indicate a code bug, a spec gap, or a business requirement change — each requires a different response.

**Triage process:**

1. **Piotr classifies** the feedback into one of three levels:

| Level | Meaning | Example | Action |
|---|---|---|---|
| **Code bug** | Implementation doesn't match the spec | "Button doesn't save" / "Wrong API response" | Fix code, re-verify, re-checkpoint. No spec changes. |
| **Spec gap** | Spec is missing a scenario or detail the user expected | "What about bulk invite?" / "This should also notify by email" | Update the functional spec, re-implement affected parts, re-verify, re-checkpoint. |
| **Business change** | The underlying business requirement changed or was misunderstood | "Actually partners should NOT see this" / "We need a different workflow" | **Escalate to the user.** Present the change, ask the user to update the App Spec (or confirm the update), then Piotr re-runs Spec Orchestrator for affected specs. |

2. **If Piotr is unsure** whether it's a spec gap or business change, he **asks the user** to classify. Present both interpretations and let the user decide.

> **No autonomous re-dispatch to om-product-manager.** Business changes surface to the user, who decides whether to re-engage Mat for a full App Spec revision or handle it as a scoped update. This prevents circular om-cto ↔ om-product-manager loops.

3. **After triage:**
   - Code bug → Piotr fixes autonomously
   - Spec gap → Piotr updates the functional spec, then re-implements
   - Business change → User confirms App Spec update → Piotr re-runs spec writing for affected specs → user re-reviews → Piotr re-implements

This ensures the App Spec and functional specs stay in sync with reality. Specs are living documents, not throwaway artifacts.

### After all specs complete

> "All N specs implemented and tested.
> - Total tests: X green
> - All code reviews: passed
>
> Ready to commit/push the full feature set, or would you like to review anything?"

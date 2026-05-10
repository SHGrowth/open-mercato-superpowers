# Spec Orchestrator Mode

When Piotr receives an App Spec from Cagan (or the user provides one), he runs this flow autonomously. No user interaction until Step 5.

## Step 1 — Decompose

Read the App Spec fully. Identify independent deliverable features. Each becomes one functional spec. Order by dependencies (foundation specs first).

Output a decomposition table (internal, not shown to user yet):

| # | Feature | App Spec section | Dependencies | Estimated complexity |
|---|---------|-----------------|--------------|---------------------|

## Step 2 — Write specs

For each feature in the decomposition, dispatch subagents in parallel where independent:

**Per-feature subagent sequence:**
1. **Gap analysis** (advisory mode, Phases 1-4): What exists in OM? What's the gap? Extension vs core? Which UMES mechanism? Piotr decides — does NOT ask the user.
2. **Spec writing** (base `spec-writing` skill with dispatch context below): Produce `SPEC-YYYY-MM-DD-{slug}.md`. Receives the App Spec section + Piotr's gap analysis as input.
3. **Validation** (load `references/pre-impl-analysis.md` and follow its workflow with the dispatch context below): Check BC violations, risks, gaps. Report findings back to Piotr.
4. **Domain-specific validation** (as needed):
   - `data-model-design`: if spec involves entities, validate design
   - `system-extension`: if spec uses UMES, verify mechanism choice

Piotr embeds his technical decisions directly in each spec under a `## Technical Approach` section:

```markdown
## Technical Approach (Piotr)

- **Mode:** External extension (UMES)
- **Mechanism:** Response Enricher + Field Widget (Triad Pattern)
- **New entities:** PartnerInvitation (see Data Model section)
- **Extends:** partnerships module via widget injection
- **Rationale:** No core modification needed — UMES enricher + field widget covers all requirements
```

## Step 3 — Cross-validate

After all specs are written, Piotr runs a cross-validation pass:
- **Contradictions:** Same entity defined differently in two specs? Same event ID used for different purposes?
- **Coverage gaps:** Every App Spec user story must map to at least one functional spec. List any orphans.
- **Circular dependencies:** No spec should depend on a spec that depends on it.
- **Ordering validity:** Can specs be implemented in the proposed order without forward references?

Fix any issues by updating the affected specs.

## Step 4 — Execution plan

Produce an execution plan document:

```markdown
# Execution Plan

## Specs (in implementation order)

| # | Spec file | Feature | Depends on | Technical approach | Complexity |
|---|-----------|---------|-----------|-------------------|------------|
| 1 | SPEC-2026-04-01-user-roles.md | User roles & permissions | — | New module (loads module-scaffold reference) | Medium |
| 2 | SPEC-2026-04-01-partnerships.md | Partnership management | #1 | UMES extension of customers | High |

## Key technical decisions

1. **User roles:** New module because OM auth doesn't cover partner-specific roles (Phase 4 level 8)
2. **Partnerships:** UMES extension — enricher + widgets on customers module (Phase 4 level 5)

## Estimated total: N specs, ~M atomic commits
```

## Step 4.5 — Proxy gate

Before presenting specs to the user, collect any detail questions that arose during spec writing (ambiguities, trade-off choices, gap decisions). Consult `references/user-proxy.md` (the proxy reference) with these questions. Incorporate resolved answers into the specs. Only present the escalation list alongside the specs for user review.

**The approval gate itself ("approve these specs?") goes directly to the user — the proxy does NOT make go/no-go decisions.**

## Step 5 — Present to user (ONLY checkpoint)

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

---

## Dispatch Context: Spec Writing

When dispatching the base `spec-writing` skill from this orchestrator, pass this context:

- **Persona:** Adopt the "Martin Fowler" staff-engineer persona for architectural purity
- **Skip:** Open Questions gate — all business questions were answered by Cagan during App Spec creation
- **Input:** The App Spec section (workflow + user stories + success criteria) as requirements source
- **Include:** A `## Technical Approach` section in the output spec with Piotr's gap analysis decisions
- **Follow:** The normal spec-writing workflow steps but with input pre-filled (no interactive brainstorming)

## Dispatch Context: Pre-Implementation Analysis

When loading `references/pre-impl-analysis.md` from this orchestrator, apply this context on top of its workflow:

- **Proxy gate:** Before presenting the analysis report to the user, consult `references/user-proxy.md` (the proxy reference) with findings. Only escalate what the proxy can't resolve.
- **Focus:** Backward compatibility audit against the 13 contract surface categories in `BACKWARD_COMPATIBILITY.md`
- **Include:** AGENTS.md compliance check for affected modules
- **Output:** Structured remediation plan with severity levels

# Piotr Orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign om-cto into a 3-mode orchestrator (advisory, spec-writing, implementation) so that technical decisions are autonomous and users only intervene for business decisions.

**Architecture:** Add mode detection preamble to om-cto SKILL.md. Add Spec Orchestrator and Implementation Orchestrator sections with subagent dispatch patterns. Update om-product-manager handoff, om-implement-spec subagent mode, and om-spec-writing subagent mode. All changes are to SKILL.md markdown files — no code, only skill instructions.

**Tech Stack:** Markdown skill files (SKILL.md), Claude Code Skill tool invocations, subagent dispatch patterns.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `skills/om-cto/SKILL.md` | Modify (major) | Add mode detection, Spec Orchestrator, Implementation Orchestrator |
| `skills/om-product-manager/SKILL.md` | Modify (small) | Replace vague handoff with explicit Piotr dispatch |
| `skills/om-implement-spec/SKILL.md` | Modify (small) | Add subagent mode that skips Extension Mode Decision |
| `skills/om-spec-writing/SKILL.md` | Modify (small) | Add subagent mode for Piotr-dispatched spec writing |
| `hooks/session-start` | Modify (small) | Update workflow paths to reflect orchestrator flow |

---

### Task 1: Add mode detection preamble to om-cto

**Files:**
- Modify: `skills/om-cto/SKILL.md:1-10`

- [ ] **Step 1: Read current om-cto SKILL.md frontmatter and opening**

Read the file to confirm current structure before editing.

- [ ] **Step 2: Add mode detection section after the header**

Insert after the `# Piotr` header and persona description, before `## OM Platform Reference`:

```markdown
## Operating Modes

Piotr operates in three modes, auto-detected from context:

| Mode | Trigger | Behavior |
|---|---|---|
| **Advisory** | Direct questions, gap analysis, PR review, standalone invocation | Interactive Q&A with user. Current behavior, unchanged. |
| **Spec Orchestrator** | Mat hands off App Spec, or user says "write specs from app spec" | Autonomous: decompose App Spec → write functional specs → cross-validate → produce execution plan → present to user for review. |
| **Implementation Orchestrator** | User approves specs + execution plan, or user says "build" / "implement approved specs" | Autonomous per-spec: dispatch om-implement-spec → verify → checkpoint with user between specs. |

### Mode detection rules

1. If an App Spec document was just completed by Mat (om-product-manager) → **Spec Orchestrator**
2. If the user references approved specs and says "build", "implement", "start", "go" → **Implementation Orchestrator**
3. Everything else → **Advisory** (existing behavior, no changes)

When in Spec Orchestrator or Implementation Orchestrator mode, Piotr makes ALL technical decisions autonomously. He does NOT ask the user "Extension or Core?", "Which UMES mechanism?", or "Should I create a new module?" — he decides using his Phase 3+4 logic and the om-system-extension / om-module-scaffold / om-eject-and-customize skills.
```

- [ ] **Step 3: Verify the edit reads correctly**

Read `skills/om-cto/SKILL.md` lines 1-40 to confirm the new section fits naturally.

- [ ] **Step 4: Commit**

```bash
git add skills/om-cto/SKILL.md
git commit -m "feat(om-cto): add 3-mode detection preamble (advisory/spec/impl)"
```

---

### Task 2: Add Spec Orchestrator mode to om-cto

**Files:**
- Modify: `skills/om-cto/SKILL.md` (append before Rules section)

- [ ] **Step 1: Read the end of om-cto SKILL.md to find insertion point**

Find the `## Flow` section — the new Spec Orchestrator section goes before it.

- [ ] **Step 2: Insert Spec Orchestrator section before `## Flow`**

```markdown
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
```
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
```

- [ ] **Step 3: Verify the section reads correctly in context**

Read `skills/om-cto/SKILL.md` around the insertion point.

- [ ] **Step 4: Commit**

```bash
git add skills/om-cto/SKILL.md
git commit -m "feat(om-cto): add Spec Orchestrator mode — autonomous spec writing"
```

---

### Task 3: Add Implementation Orchestrator mode to om-cto

**Files:**
- Modify: `skills/om-cto/SKILL.md` (append after Spec Orchestrator, before `## Flow`)

- [ ] **Step 1: Insert Implementation Orchestrator section**

```markdown
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
> - **Report a bug** → I diagnose and fix
> - **Request a change** → I update the spec and re-implement"

**Step 4 — Handle user response.**
- "next" / "continue" / "ok" → proceed to next spec
- Bug report → dispatch om-troubleshooter, fix, re-run verification, re-checkpoint
- Change request → update spec, re-implement affected parts, re-verify, re-checkpoint

### After all specs complete

> "All N specs implemented and tested.
> - Total tests: X green
> - All code reviews: passed
>
> Ready to commit/push the full feature set, or would you like to review anything?"
```

- [ ] **Step 2: Verify section reads correctly**

Read the full om-cto SKILL.md to confirm all three modes + existing advisory content coexist.

- [ ] **Step 3: Commit**

```bash
git add skills/om-cto/SKILL.md
git commit -m "feat(om-cto): add Implementation Orchestrator mode — autonomous per-spec execution"
```

---

### Task 4: Update `## Flow` section in om-cto

**Files:**
- Modify: `skills/om-cto/SKILL.md` (replace existing `## Flow` section)

- [ ] **Step 1: Replace the Flow section**

Replace:
```markdown
## Flow

```
piotr → brainstorming → planning → implementation
piotr → code-review
```

If unnecessary — stop. Best code is code you didn't write.
```

With:
```markdown
## Flow

```
Advisory:     user question → piotr investigates → findings report
Spec:         mat hands off app spec → piotr decomposes → writes specs → cross-validates → user reviews → approved
Implement:    user approves → piotr dispatches per-spec → implement → test → review → user tests on localhost → next spec
Standalone:   piotr → code-review (unchanged)
```

If unnecessary — stop. Best code is code you didn't write.
```

- [ ] **Step 2: Commit**

```bash
git add skills/om-cto/SKILL.md
git commit -m "feat(om-cto): update Flow section to reflect 3 modes"
```

---

### Task 5: Update om-product-manager handoff to Piotr

**Files:**
- Modify: `skills/om-product-manager/SKILL.md:353,377-385`

- [ ] **Step 1: Read the handoff area**

Read lines 340-385 to confirm exact text to replace.

- [ ] **Step 2: Replace the vague handoff with explicit Piotr dispatch**

Replace the final line (after the flow graph):
```markdown
Mat delivers the right thing. Vernon challenges the domain model. Piotr ensures it's mapped right. All three agree before any code.
```

With:
```markdown
Mat delivers the right thing. Vernon challenges the domain model. Piotr ensures it's mapped right. All three agree before any code.

## Handoff to Piotr

After Phase 5 (Handoff) is complete and the App Spec is finalized:

**Dispatch Piotr in Spec Orchestrator mode.** He will autonomously:
1. Decompose the App Spec into functional specs
2. Write each spec using om-spec-writing (with gap analysis from om-cto advisory logic)
3. Cross-validate all specs for contradictions and coverage
4. Produce an execution plan
5. Present specs + plan to the user for review

Do NOT invoke writing-plans or brainstorming after Mat. The next step is always Piotr's Spec Orchestrator. Mat's job is done when the App Spec is complete.
```

- [ ] **Step 3: Also update the flow graph terminal node**

In the dot graph, replace:
```
"brainstorming → planning → implementation" [shape=box style=filled fillcolor=lightgreen];
```

With:
```
"Piotr: Spec Orchestrator" [shape=box style=filled fillcolor=lightgreen];
```

And update the edge:
```
"Phase 5: Handoff" -> "Piotr: Spec Orchestrator";
```

- [ ] **Step 4: Verify the edit**

Read the modified lines to confirm correctness.

- [ ] **Step 5: Commit**

```bash
git add skills/om-product-manager/SKILL.md
git commit -m "feat(om-product-manager): explicit handoff to Piotr Spec Orchestrator after App Spec"
```

---

### Task 6: Add subagent mode to om-implement-spec

**Files:**
- Modify: `skills/om-implement-spec/SKILL.md:30-59` (Extension Mode Decision section)

- [ ] **Step 1: Read the Extension Mode Decision section**

Read lines 30-59 to confirm exact text.

- [ ] **Step 2: Add subagent mode gate before Extension Mode Decision**

Insert immediately after `## Pre-Flight` section (after line 29), before `## Extension Mode Decision`:

```markdown
## Subagent Mode Detection

If this skill was invoked by Piotr (om-cto) as part of the Implementation Orchestrator, the spec will contain a `## Technical Approach` section with Piotr's decisions (extension vs core, UMES mechanism, module strategy).

**When Technical Approach section exists in the spec:**
- Skip the Extension Mode Decision — Piotr already decided
- Read the Technical Approach section for: mode (external/core), mechanism, entities, extensions
- Proceed directly to Implementation Workflow using Piotr's decisions
- Pipeline Lock is active — follow the full pipeline without stopping

**When Technical Approach section does NOT exist** (standalone invocation):
- Follow the normal Extension Mode Decision flow below (ask the user)

This allows om-implement-spec to work both as an autonomous subagent (dispatched by Piotr) and as a standalone skill (invoked directly by user).
```

- [ ] **Step 3: Wrap Extension Mode Decision in a conditional**

Add a note at the top of Extension Mode Decision:

Replace:
```markdown
## Extension Mode Decision (Mandatory First Step)

Before writing any code, ask the user:
```

With:
```markdown
## Extension Mode Decision (Standalone Mode Only)

**Skip this section if the spec has a `## Technical Approach` section** — Piotr already made this decision. Go directly to Implementation Workflow.

When invoked standalone (no Technical Approach in spec), ask the user:
```

- [ ] **Step 4: Verify the edit**

Read the modified section to confirm it reads correctly in both modes.

- [ ] **Step 5: Commit**

```bash
git add skills/om-implement-spec/SKILL.md
git commit -m "feat(om-implement-spec): add subagent mode — skip Extension Mode Decision when Piotr decided"
```

---

### Task 7: Add subagent mode to om-spec-writing

**Files:**
- Modify: `skills/om-spec-writing/SKILL.md:7-28` (Workflow section)

- [ ] **Step 1: Read the current workflow**

Read the file to confirm structure.

- [ ] **Step 2: Add subagent mode section before the Workflow**

Insert after the `# Spec Writing & Review` header, before `## Workflow`:

```markdown
## Subagent Mode Detection

If this skill was dispatched by Piotr (om-cto Spec Orchestrator), it receives:
- An App Spec section (workflow + user stories + success criteria) as input
- Piotr's gap analysis (what exists, what to build, technical approach)

**When dispatched by Piotr:**
- Skip the Open Questions gate — all business questions were answered by Mat during App Spec creation
- Use the App Spec section as the requirements source (no interactive brainstorming)
- Use Piotr's gap analysis to inform architecture and technical decisions
- Include a `## Technical Approach` section in the output spec with Piotr's decisions
- Follow the normal workflow steps 1-10 but with input pre-filled

**When invoked standalone** (user starts a new spec directly):
- Follow the normal interactive workflow below (with Open Questions gate)
```

- [ ] **Step 3: Verify the edit**

Read the full file to confirm both modes are clear.

- [ ] **Step 4: Commit**

```bash
git add skills/om-spec-writing/SKILL.md
git commit -m "feat(om-spec-writing): add subagent mode for Piotr-dispatched spec writing"
```

---

### Task 8: Update session-start hook workflow paths

**Files:**
- Modify: `hooks/session-start`

- [ ] **Step 1: Read current workflow paths in session-start**

Read the file to find the workflow paths section.

- [ ] **Step 2: Update workflow paths to reflect orchestrator**

Replace:
```
1. **Build a feature** — om-product-manager → om-cto → om-spec-writing → om-implement-spec → om-code-review
2. **Implement a spec** — om-pre-implement-spec → om-implement-spec → om-code-review
```

With:
```
1. **Build a feature** — om-product-manager (brainstorm with you) → om-cto (autonomously writes specs + plan) → you review → om-cto (autonomously implements spec by spec, you test between each)
2. **Implement a spec** — om-implement-spec → om-code-review (or give specs to om-cto to orchestrate)
```

- [ ] **Step 3: Verify hook still produces valid JSON**

```bash
cd /tmp && mkdir -p test-hook && cd test-hook && echo '{"dependencies":{"@open-mercato/core":"*"}}' > package.json && CLAUDE_PLUGIN_ROOT="/Users/maciejgren/Documents/om-claude-plugin" bash /Users/maciejgren/Documents/om-claude-plugin/hooks/session-start 2>&1 | python3 -m json.tool > /dev/null && echo "VALID" || echo "INVALID" && rm -rf /tmp/test-hook
```

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "feat(session-start): update workflow paths to reflect Piotr orchestrator"
```

---

### Task 9: Update design spec status and push

**Files:**
- Modify: `docs/specs/2026-04-01-piotr-orchestrator-design.md:4`

- [ ] **Step 1: Update status**

Change:
```markdown
**Status:** Design approved, pending implementation
```

To:
```markdown
**Status:** Implemented
```

- [ ] **Step 2: Final commit and push**

```bash
git add docs/specs/2026-04-01-piotr-orchestrator-design.md
git commit -m "docs: mark Piotr orchestrator design as implemented"
git push
```

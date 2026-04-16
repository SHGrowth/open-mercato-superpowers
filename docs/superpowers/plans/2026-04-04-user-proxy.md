# User Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pipeline-level proxy agent that intercepts questions before they reach the user, resolves what it can from app spec and learned lessons, and escalates only genuine business judgment calls.

**Architecture:** New skill `om-user-proxy` with a SKILL.md that defines the resolution logic, voice, and learning behavior. Session-start hook updated to introduce the proxy on first use and announce it on return. Other skills updated to invoke the proxy before presenting questions to the user.

**Tech Stack:** Markdown skill definitions, bash hook (session-start), markdown lesson files.

---

### Task 1: Create the om-user-proxy skill

**Files:**
- Create: `skills/om-user-proxy/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p skills/om-user-proxy
```

- [ ] **Step 2: Write SKILL.md**

Create `skills/om-user-proxy/SKILL.md` with this content:

```markdown
---
name: om-user-proxy
description: "Pipeline-level proxy that answers routine questions on the user's behalf. Invoked by other skills before presenting questions, findings, or decisions to the user. Resolves from app spec, app-specific lessons, global lessons, and contextual reasoning. Escalates only what genuinely needs human judgment."
---

# User Proxy

You are the user's shadow — you speak in their voice, using their reasoning style. You are NOT a separate character or advisor. When you resolve a question, say what the user would say: "I'd defer this because we always prioritize simplicity in early phases."

## Onboarding

### First time (no proxy-lessons.md exists)

When invoked and no app-specific lessons file exists yet, ask the user to name their proxy:

> "I'd like to set up your proxy. They'll answer routine agent questions on your behalf so you only deal with what genuinely needs your judgment. They learn how you think over time. What would you like to name them?"

Once named, create the app-specific lessons file at `app-spec/proxy-lessons.md`:

```markdown
---
proxy_name: [chosen name]
---

# Proxy Lessons

Decisions made on behalf of the user, scoped to this app.
```

### Returning sessions (proxy-lessons.md exists)

Read the lessons file header for the proxy name, count lessons. Report:

> "[Name] is active. [N] app lessons, [M] global lessons."

## Resolution Logic

When an agent passes you a list of questions/findings/decisions, attempt resolution in this order:

### Step 1 — Check app spec

Read the app spec (`app-spec/app-spec.md` or equivalent). Is the answer already documented? If found: resolve, cite the section.

### Step 2 — Check app-specific lessons

Read `app-spec/proxy-lessons.md`. Has the user made this type of decision before in this app? If found: resolve, cite the lesson.

### Step 3 — Check global lessons

Read the global proxy lessons from the memory system. Has the user shown a general pattern across projects? If found: resolve, cite the pattern.

### Step 4 — Reason from context

Can the answer be derived from the combination of what's known? Only resolve if:
- The reasoning chain is short (1-2 hops)
- The conclusion is unambiguous
- You are resolving a **fact**, not an **opinion**

If you find yourself making a judgment call about business priorities, trade-offs, or risk tolerance — escalate. The proxy resolves facts, not opinions.

### Step 5 — Escalate

Can't resolve. Pass to user as-is.

## Output Format

```
[Proxy name] resolved:
- Q: "[question text]"
  → [answer] ([source: app spec §X / lesson from YYYY-MM-DD / reasoning])

Needs your input:
- Q: "[question text]"
  ([why proxy can't resolve — no prior decision, business judgment needed, etc.])
```

If ALL questions are resolved, still show the resolved list so the user knows what was decided on their behalf.

If NO questions can be resolved, say so briefly and present them all.

## Learning from Corrections

When the user overrides a proxy decision:

1. Ask for the principle: "I thought X because [reasoning]. What should I know instead?"
2. Ask for the scope:
   - "Always, everywhere" → save to global lessons (`~/.claude/projects/<project>/memory/proxy-lessons-global.md`)
   - "For this app" → save to app-specific lessons (`app-spec/proxy-lessons.md`)
   - "Just this time" → don't persist

### Lesson format

Append to the appropriate lessons file:

```markdown
- **Decision:** [what was decided]
  **Context:** [what question triggered it]
  **Reasoning:** [why — in user's words, not proxy's interpretation]
  **Date:** [YYYY-MM-DD]
```

## What NOT to intercept

Even if invoked, pass these through to the user without attempting resolution:

- **Phase gates** — "specs approved, start implementing?", "ready to merge?"
- **Discovery questions** — Cagan's Phase 0 business questions ("Who pays?", "What's the flywheel?")
- **Empirical verification** — "does this work on localhost?", "do tests pass?"
- **First-time domain questions** — anything where no prior context exists AND the question requires business judgment

If the calling skill incorrectly sends a phase gate or discovery question, return it unchanged with a note: "This is a [phase gate / discovery question] — routing directly to user."
```

- [ ] **Step 3: Verify skill is detected**

```bash
grep -r "om-user-proxy" skills/om-user-proxy/SKILL.md
```

Expected: the file exists and contains the skill definition.

- [ ] **Step 4: Commit**

```bash
git add skills/om-user-proxy/SKILL.md
git commit -m "feat(om-user-proxy): add user proxy skill — pipeline-level decision interceptor"
```

---

### Task 2: Update session-start hook with proxy introduction

**Files:**
- Modify: `hooks/session-start:28-98` (the OM_CONTEXT block)

- [ ] **Step 1: Add proxy section to the context message**

In `hooks/session-start`, inside the `OM_CONTEXT` heredoc, after the `### Rules` section (line 67) and before `## Available OM Skills` (line 69), add:

```markdown
### User Proxy

After greeting and pipeline guidance, check for the user proxy:

- If `app-spec/proxy-lessons.md` exists in the working directory → proxy is set up. Read the file for the proxy name and lesson count. Announce: "[Name] is active. [N] app lessons, [M] global lessons."
- If no proxy-lessons.md exists → introduce the proxy concept and ask the user to name them. See the `om-user-proxy` skill for the full onboarding flow.

The proxy is invoked by other skills before presenting questions to the user. You do not need to invoke it during session-start — it activates when skills call it.
```

- [ ] **Step 2: Add om-user-proxy to the skills list**

In the `## Available OM Skills` section, add under a new heading after **Testing & Quality:**:

```markdown
**Pipeline:**
- om-user-proxy: User's decision proxy — intercepts questions, resolves from context, escalates only business judgment calls
```

- [ ] **Step 3: Verify hook syntax**

```bash
bash -n hooks/session-start
```

Expected: no syntax errors.

- [ ] **Step 4: Commit**

```bash
git add hooks/session-start
git commit -m "feat(hooks): add user proxy introduction and status to session-start"
```

---

### Task 3: Update om-product-manager to invoke the proxy

**Files:**
- Modify: `skills/om-product-manager/SKILL.md`

- [ ] **Step 1: Read the current skill**

Read `skills/om-product-manager/SKILL.md` to find where findings are presented to the user (after review/analysis, after Vernon challenger findings).

- [ ] **Step 2: Add proxy gate after review findings**

After the section that presents review findings to the user (the triage step that failed in the app-spec-review session), add:

```markdown
### Proxy Gate

Before presenting findings, triage results, or analysis to the user, invoke `om-user-proxy` as a subagent with the full list of questions/findings/decisions. The proxy resolves what it can and returns only the items that need the user's judgment.

**Do NOT present raw finding lists to the user.** Always run through the proxy first.

**Exception:** Phase 0 discovery questions (business model, flywheel, goals, scope) go directly to the user — the proxy has nothing to learn from yet.
```

- [ ] **Step 3: Commit**

```bash
git add skills/om-product-manager/SKILL.md
git commit -m "feat(om-product-manager): add proxy gate before presenting findings to user"
```

---

### Task 4: Update om-cto to invoke the proxy

**Files:**
- Modify: `skills/om-cto/SKILL.md`
- Modify: `skills/om-cto/references/orchestrator-modes.md`

- [ ] **Step 1: Read orchestrator-modes.md**

Read `skills/om-cto/references/orchestrator-modes.md` to find the checkpoint and feedback triage sections.

- [ ] **Step 2: Add proxy gate to Spec Orchestrator**

In `orchestrator-modes.md`, before "Step 5 — Present to user (ONLY checkpoint)", add:

```markdown
### Step 4.5 — Proxy gate

Before presenting specs to the user, collect any detail questions that arose during spec writing (ambiguities, trade-off choices, gap decisions). Invoke `om-user-proxy` with these questions. Incorporate resolved answers into the specs. Only present the escalation list alongside the specs for user review.

**The approval gate itself ("approve these specs?") goes directly to the user — the proxy does NOT make go/no-go decisions.**
```

- [ ] **Step 3: Add proxy gate to Implementation Orchestrator feedback triage**

In `orchestrator-modes.md`, in the feedback triage section, add before the triage table:

```markdown
### Proxy pre-triage

Before presenting feedback triage to the user, invoke `om-user-proxy` with the findings. The proxy can resolve:
- **Code bugs** — always fixable without user input (proxy resolves: "fix it")
- **Spec gaps** where the answer is in the app spec — proxy resolves with citation

The proxy escalates:
- **Business changes** — always needs user judgment
- **Spec gaps** where the answer is NOT in the app spec or lessons
```

- [ ] **Step 4: Add proxy reference to SKILL.md**

In `skills/om-cto/SKILL.md`, in the operating modes table or below it, add:

```markdown
### User Proxy Integration

All modes invoke `om-user-proxy` before presenting questions or findings to the user. See the proxy skill for resolution logic. Phase gates (spec approval, per-spec go/no-go) bypass the proxy.
```

- [ ] **Step 5: Commit**

```bash
git add skills/om-cto/SKILL.md skills/om-cto/references/orchestrator-modes.md
git commit -m "feat(om-cto): add proxy gate to spec and implementation orchestrator checkpoints"
```

---

### Task 5: Update om-pre-implement-spec to invoke the proxy

**Files:**
- Modify: `skills/om-pre-implement-spec/SKILL.md`

- [ ] **Step 1: Read the current skill**

Read `skills/om-pre-implement-spec/SKILL.md` to find where the report is presented to the user.

- [ ] **Step 2: Add proxy gate before report presentation**

The skill currently says "MUST NOT modify the spec directly — propose changes in the report for user review." Before the report is presented, add:

```markdown
### Proxy Gate

Before presenting the analysis report to the user, invoke `om-user-proxy` with the proposed spec changes and remediation items. The proxy resolves items where the answer is already in the app spec or lessons (e.g., "should we add i18n keys?" → always yes per convention). Only present unresolved items to the user alongside the full report.

The proxy does NOT auto-apply spec changes — it resolves the decision ("yes, add this"), and the pre-implement skill includes it in the report as a resolved item.
```

- [ ] **Step 3: Commit**

```bash
git add skills/om-pre-implement-spec/SKILL.md
git commit -m "feat(om-pre-implement-spec): add proxy gate before presenting analysis report"
```

---

### Task 6: Update om-implement-spec to invoke the proxy

**Files:**
- Modify: `skills/om-implement-spec/SKILL.md`

- [ ] **Step 1: Read the current skill**

Read `skills/om-implement-spec/SKILL.md` to find the standalone extension-vs-core decision section.

- [ ] **Step 2: Add proxy gate for standalone decisions**

In the section about "When invoked standalone (no Technical Approach in spec), ask the user", add:

```markdown
### Proxy Gate

Before asking the user for extension-vs-core decision, invoke `om-user-proxy`. The proxy can resolve this if:
- The app spec or lessons contain a prior decision for this module/entity type
- Piotr has already documented the approach in a related spec

If the proxy resolves it, proceed with the resolved answer. If not, ask the user as before.
```

- [ ] **Step 3: Commit**

```bash
git add skills/om-implement-spec/SKILL.md
git commit -m "feat(om-implement-spec): add proxy gate for standalone extension-vs-core decisions"
```

---

### Task 7: Update om-code-review to invoke the proxy

**Files:**
- Modify: `skills/om-code-review/SKILL.md`

- [ ] **Step 1: Read the current skill**

Read `skills/om-code-review/SKILL.md` to find the template sync prompt section.

- [ ] **Step 2: Add proxy gate for template sync**

In the template sync section ("ask the user whether to sync now"), add:

```markdown
### Proxy Gate

Before asking the user about template sync, invoke `om-user-proxy`. The proxy resolves: "yes, sync" if the drift is in files the current changes touch (obvious fix). Escalates if the drift is in unrelated files (user might want to handle separately).
```

- [ ] **Step 3: Commit**

```bash
git add skills/om-code-review/SKILL.md
git commit -m "feat(om-code-review): add proxy gate for template sync prompt"
```

---

### Task 8: Bump version and push

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Bump version to 1.5.0**

In `package.json`, change `"version": "1.4.0"` to `"version": "1.5.0"`.

- [ ] **Step 2: Commit and push**

```bash
git add package.json
git commit -m "chore: bump version to 1.5.0"
git push
```

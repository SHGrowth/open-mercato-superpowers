# User Proxy — Design Spec

Pipeline-level agent that intercepts questions and findings before they reach the user. Resolves what it can from existing context, escalates only what genuinely needs human judgment. Learns the user's decision patterns over time.

## 1. Identity & Onboarding

### First-time flow

After session-start detects an OM project, detects pipeline state, and presents guidance — introduce the proxy:

> "One more thing — I'd like to set up your proxy. They'll answer routine agent questions on your behalf so you only deal with what genuinely needs your judgment. They learn how you think over time. What would you like to name them?"

User names them (e.g., "Alex"). Proxy is created with an empty app-specific lessons file. Name stored in the lessons file header.

### Returning sessions

If proxy lessons file exists with a `proxy_name`, skip introduction:

> "[Name] is active. [N] app lessons, [M] global lessons."

### Voice

The proxy speaks as the user would — "I'd say defer this because we always prioritize simplicity in early phases" — not as a separate character analyzing the user. When reporting decisions, it uses the user's reasoning style, not its own.

## 2. Decision Resolution Logic

When an agent is about to ask the user something, it invokes the proxy with the question(s). The proxy attempts resolution in order:

### Step 1 — Check app spec

Is the answer already documented? (e.g., "should PM approve tier changes?" — yes, app spec says manual approval always). If found: resolve, cite the source.

### Step 2 — Check app-specific lessons

Has the user made this type of decision before in this app? (e.g., "defer suspension features" from the tier validity session). If found: resolve, cite the lesson.

### Step 3 — Check global lessons

Has the user shown a general pattern? (e.g., "prefers manual over automated for governance"). If found: resolve, cite the pattern.

### Step 4 — Reason from context

Can the answer be derived from the combination of what's known? (e.g., "should the cross-story impact matrix include this story?" — yes, because the story changes entity state and other stories reference that entity). If derivable: resolve, explain the reasoning.

**Guardrail:** Only resolve if the reasoning chain is short (1-2 hops) and the conclusion is unambiguous. If the proxy finds itself making a judgment call about business priorities, trade-offs, or risk tolerance — escalate. The proxy resolves facts, not opinions.

### Step 5 — Escalate

Can't resolve. Pass to user as-is.

### Output format

```
[Proxy name] resolved:
- Q: "Should tier expiry trigger automatic suspension?"
  → No — deferred to GitHub issue #27 (app spec §3.5, lesson: "suspension is a future feature")
- Q: "Extension or core for the banner widget?"
  → Extension via UMES widget injection (Piotr's standard approach for dashboard widgets)

Needs your input:
- Q: "Grace period — 30 days or 60 days for new partner tier?"
  (No prior decision or pattern. Business judgment needed.)
```

## 3. Learning & Correction

### When the proxy resolves correctly

No action needed. The existing lesson or app spec was sufficient.

### When the user overrides

The proxy asks two questions:

1. **What's the principle?** "I thought X because [reasoning]. What should I know instead?"
2. **Where does this apply?**
   - "Always, everywhere" → saved to global lessons
   - "For this app" → saved to app-specific lessons
   - "Just this time" → not persisted

### Storage locations

| Scope | Location | Example |
|-------|----------|---------|
| Global | `~/.claude/projects/<project>/memory/proxy-lessons-global.md` | "User prefers manual governance over automated" |
| App-specific | `apps/<app>/app-spec/proxy-lessons.md` | "PRM: tier suspension is explicitly deferred, never auto-resolve" |
| Session-only | Not persisted | "Use 60 days this time because we're demo-ing next week" |

### Lesson format

```markdown
- **Decision:** [what was decided]
  **Context:** [what question triggered it]
  **Reasoning:** [why — in user's words, not proxy's interpretation]
  **Date:** 2026-04-04
```

### Proxy name storage

App-specific lessons file header:

```markdown
---
proxy_name: Alex
---
```

Each app can have its own named proxy, or the same name carries across.

## 4. Pipeline Integration

### Skills that get the proxy gate

Every skill that presents questions, findings, or decisions to the user:

| Skill | Current user touchpoint | Proxy gate location |
|-------|------------------------|---------------------|
| om-product-manager (Cagan) | Review findings triage | Before presenting findings to user |
| om-cto Spec Orchestrator | Detail questions during spec writing | Before asking user mid-spec (approval gate itself stays with user) |
| om-cto Implementation Orchestrator | Feedback triage (code bug / spec gap / business change) | Before presenting triage to user (per-spec go/no-go stays with user) |
| om-pre-implement-spec | Proposed spec changes | Before presenting the report |
| om-implement-spec | Extension-vs-core decision (standalone) | Before asking |
| om-code-review | Template sync prompt | Before asking |

### What the proxy does NOT intercept

- **Hard approval gates** — "specs approved, start implementing?" stays with the user. The proxy resolves detail questions, not go/no-go calls on entire phases.
- **Cagan's Phase 0 business discovery** — "Who pays? What's the flywheel?" are exploratory questions that build the domain model. The proxy has nothing to learn from yet.
- **User testing on localhost** — "does this work?" is empirical, not a judgment call.

**Rule:** The proxy intercepts **findings, analysis triage, and detail decisions**. It does NOT intercept **phase gates, discovery questions, or empirical verification**.

### How skills invoke it

Each skill calls `om-user-proxy` as a subagent, passing the questions/findings as input. The proxy returns resolved answers + escalation list. The skill proceeds with resolved answers and only presents the escalation list to the user.

## 5. Session-Start Changes

### Hook context message additions

Two additions to the session-start context block (no changes to bash script logic):

1. **First time** — after pipeline state detection: introduce proxy, ask for name
2. **Returning** — if proxy lessons file detected: announce proxy is active with lesson count

### Implementation artifacts

| Artifact | Type |
|----------|------|
| `skills/om-user-proxy/SKILL.md` | New skill |
| `hooks/session-start` context message | Updated |
| `apps/<app>/app-spec/proxy-lessons.md` | Created per-app on first use |
| `~/.claude/projects/<project>/memory/proxy-lessons-global.md` | Created on first global lesson |

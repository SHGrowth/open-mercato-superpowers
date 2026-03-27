# App Spec: [App Name]

> App Spec is a business architecture document that sits above technical specs.
> It captures domain knowledge, validates cross-spec consistency, and ensures
> the app solves a real business problem using the platform correctly.
>
> This document is the SINGLE SOURCE OF TRUTH for what this app is, who it serves,
> and how it maps to Open Mercato. Technical specs are generated from this document.
> If a spec contradicts this document, this document wins.
>
> Each section has a checklist with owner (Mat or Piotr). Section is done when all checks pass.

---

## 1. Business Context `Mat`

### 1.1 Business Model

[Describe: what the app does, how the business makes money, who pays.]

**Flywheel:**
```
[Draw the reinforcing loop that makes the system more valuable over time]
```

#### Checklist
- [ ] Paying customer identified — who writes the check? What do they get?
- [ ] Flywheel articulated — the reinforcing loop, not just "users benefit"

### 1.2 Business Goals

**Primary goal:** [What problem does this app solve? For whom?]

**Secondary goal (example app):** [If applicable — what platform patterns does this app teach?]

**What is NOT important:** [Explicit scope exclusions. What this app will NOT do.]

#### Checklist
- [ ] Primary goal stated with measurable outcome
- [ ] Scope exclusions listed — what's out and why

### 1.3 Ubiquitous Language

> DDD: one term = one meaning everywhere. This glossary IS the ubiquitous language.

| Term | Definition | Source of data | Period |
|------|-----------|----------------|--------|
| | | | |

#### Checklist
- [ ] Every domain term defined once
- [ ] Same word = same meaning across all specs and conversations
- [ ] Source of data and period specified per term

### 1.4 Domain Model

> DDD: document the domain entities, rules, invariants, and value calculations specific to this app.
> Structure this section however the domain demands — there is no fixed format.
>
> Examples of what belongs here (depending on the domain):
> - Tier/level definitions with thresholds and governance rules
> - KPI formulas with anti-gaming rules
> - Business rules: permissions hierarchy, data ownership, cross-org visibility
> - Domain invariants: what must always be true
> - Value calculations: how scores, ratings, or statuses are derived
> - Entity field definitions with types, constraints, and relations

[Document your domain model here. Use subsections as needed.]

#### Checklist
- [ ] Domain entities identified with clear ownership
- [ ] Domain rules documented — invariants, constraints, calculations
- [ ] If there are levels/tiers: thresholds, benefits, governance rules (evaluation, grace period, downgrade, audit)
- [ ] If there are KPIs/scores: complete formulas with input source, period, anti-gaming rules
- [ ] Access control rules documented — who sees/does what, cross-org visibility
- [ ] Data ownership per entity — who creates, who reads, who updates, system vs user
- [ ] **Entity fields defined precisely** — every domain entity has its fields listed with: key, type (text/select/dictionary/relation/boolean/integer/float), multi-value or not, and required-for-creation flag. Vague descriptions like "agency profile data" or "case study information" are not acceptable — implementation will guess wrong.

> **Weak vs precise field definitions:**
>
> | Weak (will cause bugs) | Precise (implementation-ready) |
> |----------------------|-------------------------------|
> | "Case study has industry and tech info" | `industry` (dictionary, multi, required), `technologies` (dictionary, multi, required), `project_type` (select) |
> | "Company profile with services" | `services` (dictionary, multi), `industries` (dictionary, multi), `tech_capabilities` (dictionary, multi), `team_size_bucket` (select) |
> | "Budget information" | `budget_known` (boolean), `budget_bucket` (select, required), `budget_min_usd` (float), `budget_max_usd` (float) |
> | "Track deal progress" | `wip_registered_at` (datetime, system-set, immutable once stamped, UTC) |
> | "License deal record" | `license_identifier` (text, required), `attributed_agency_id` (relation, required), `type` (select: enterprise), `status` (select: won), `is_renewal` (boolean), `closed_at` (datetime), `industry_tag` (dictionary) — unique key: `(license_identifier, year)` |
>
> Rule of thumb: if a developer reading the field definition has to ask "what type is this?" or "is this required?" — the definition is too vague.

---

## 2. Identity Model `Mat`

> SINGLE SOURCE OF TRUTH. If any spec contradicts this, update the spec.

| Persona | Role key | Identity | Org scope | Sees | Does |
|---------|----------|----------|-----------|------|------|
| | | User / CustomerUser | | | |

**Portal Decision Framework:**

Every persona external to the operating organization is a candidate for CustomerUser + Portal.

```
External persona?
├─ NO → User + Backend + RBAC
└─ YES → Needs brand separation or different UX than CRM?
          ├─ NO, CRM UI is fine → User + Backend + RBAC
          └─ YES → CustomerUser + Portal
```

> **Portal red flag:** If a portal persona needs DataTable, pipeline views, or rich CRUD on many entities — reconsider. Portal doesn't have these building blocks. Exception: conscious decision for custom UX confirmed in decision log.
>
> **Backend red flag:** If a User persona is external, temporary, and sees 2-3 simple views — consider Portal. Agent generates pages, and the identity model stays clean.
>
> **Agentic cost note:** Portal requires custom pages (no DataTable/CrudForm). In agentic workflow the agent generates them from this spec. This is not a blocker — but §3.5 MUST spec every portal page with enough detail for an agent to implement without guessing. Each portal page = minimum 1 atomic commit in §4 gap analysis.

**Portal decision:** [USED / NOT USED]

**If USED — per persona justification:**

| Portal persona | Why Portal, not Backend? | Custom pages needed? |
|---|---|---|
| | | |

**If NOT USED — why:**
[Justification — e.g., "All personas need CRM access. Portal doesn't expose CRM. One identity system simpler."]

**Decision log:**
[Per persona: why this identity type? What modules do they need? What was the alternative and why it was rejected?]

#### Checklist
- [ ] Every persona has ONE identity type — User or CustomerUser, no "maybe both" `Mat`
- [ ] Identity decision justified per persona — what modules they need drives the choice `Mat`
- [ ] No persona has two accounts — if someone needs both User and CustomerUser, the model is wrong `Piotr`
- [ ] Org scoping defined per role — who sees which orgs, read-only vs read-write `Piotr`
- [ ] Portal decision justified with decision tree — not just "used/not used" `Mat`
- [ ] If Portal USED: every portal persona has custom page estimate `Piotr`
- [ ] If Portal USED: §3.5 includes Portal Pages subsection with full page specs `Mat`

---

## 3. Workflows `Mat`

> Each workflow traces to ROI. If a workflow doesn't move a KPI or enable one that does, cut it.

### WF[N]: [Workflow Name]

**Journey:** [step1] -> [step2] -> ... -> [value delivered]

**ROI:** [Specific measurable business outcome]

**Key personas:** [Who's involved at each step]

**Boundaries:**
- Starts when: [trigger]
- Ends when: [completion criteria]
- NOT this workflow: [what's explicitly out of scope]

**Edge cases:**
1. [scenario] -> [what should happen] -> [risk if unhandled]
2. ...

**OM readiness (per step):**

| Step | OM Module | Gap? | Notes |
|------|-----------|------|-------|
| | | | |

[Repeat per workflow]

#### Checklist (per workflow)
- [ ] End-to-end journey — first touchpoint to value delivery, no gaps `Mat`
- [ ] Measurable ROI — specific metric that moves, not "users benefit" `Mat`
- [ ] Boundaries — explicit start, end, and NOT-this-workflow `Mat`
- [ ] 3-5 edge cases — high probability production scenarios `Mat`
- [ ] Every step mapped to OM module `Piotr`

#### Checklist (overall)
- [ ] 3-7 core workflows defined `Mat`
- [ ] No workflow requires >200 lines of new code — if it does, you missed a platform capability `Piotr`

---

## 3.5 UI Architecture `Mat + Krug`

> Defines what each persona sees in the UI. Navigation, pages, dashboard widgets, key user flows.
> Mat drafts from user stories. Krug reviews for clarity and task completion.
> Everything here uses OM's existing UI building blocks — no custom components.

### Navigation (per role)

> What sidebar groups and items does each role see? Order matters — most-used first.

| Role | Sidebar groups | Notes |
|------|---------------|-------|
| | | |

### Dashboard Widgets (per role)

> What does each role see on their dashboard after login? Widgets should answer "what do I need to do right now?"

| Widget | Roles that see it | Data shown | Click-through |
|--------|------------------|------------|---------------|
| | | | |

### Custom Pages

> Pages beyond standard CRM CRUD. Each page is a backend page auto-discovered from `backend/<module>/<path>/page.tsx`.

| Page | URL pattern | Role | Purpose | OM pattern |
|------|------------|------|---------|------------|
| | `/backend/...` | | | CrudForm / DataTable / custom |

### Portal Pages (when §2 Portal = USED)

> Portal pages are custom React pages at `src/modules/<module>/frontend/[orgSlug]/portal/<path>/page.tsx`.
> Portal has NO DataTable, CrudForm, or pipeline views — every page is custom code.
> In agentic workflow the agent generates pages from this spec.
> The spec MUST be precise enough for an agent to implement without guessing.

| Page | URL pattern | Portal role | Purpose | User actions | Stage gate | OM pattern |
|------|------------|-------------|---------|--------------|------------|------------|
| | `/portal/...` | | What the user accomplishes | What they can do | Stage/lifecycle condition, or "always" | portal dashboard widget / custom page / portal menu injection / portal form |

> **Stage gate:** page available only at certain workflow/lifecycle stages. If always available, write "always".
> Disabled pages show explanation tooltip — never hidden (preserve spatial memory).
>
> **Rules:**
> - Each page = minimum 1 atomic commit in §4 gap analysis. Estimate per page based on: data fetching complexity, form validation, real-time events, role-conditional content.
> - If page uses real-time (SSE): list events — maps to event architecture.
> - If page has stage gate: maps to workflow state — verify in §3 Workflows.

### Widget Injections

> Where custom widgets inject into existing OM pages (detail pages, list pages).

| Widget | Injects into | Injection spot | Data |
|--------|-------------|---------------|------|
| | | | |

### Key User Flows

> For each persona's primary task, trace the click path from login to completion.

| Persona | Task | Flow (login → done) | Clicks | Notes |
|---------|------|---------------------|--------|-------|
| | | page → page → action → result | | |

### Empty States

> What does a first-time user see? Empty states should guide, not confuse.

| Page/Widget | Empty state message | Action |
|-------------|-------------------|--------|
| | "No X yet. [Create one]" | Link to create page |

#### Checklist
- [ ] Every persona has a defined login-to-primary-task flow `Mat`
- [ ] Navigation grouping matches how users think about their work `Krug`
- [ ] Dashboard widgets answer "what to do next" not just "data" `Krug`
- [ ] Empty states are helpful, not blank pages `Krug`
- [ ] Custom pages use OM patterns (CrudForm, DataTable) — no custom UI `Piotr`
- [ ] Click count from login to primary task is ≤ 3 for each persona `Krug`
- [ ] If Portal USED: every portal page specced in table with OM pattern `Mat`
- [ ] If Portal USED: real-time events mapped per page that uses SSE `Piotr`
- [ ] If Portal USED: empty states + stage gates defined `Krug`

---

## 4. Workflow Gap Analysis `Piotr`

> Gap analysis maps each workflow step to OM platform capability.

### Gap Scoring — Atomic Commits (Ralph Loop)

Each gap is measured in **atomic commits** — one self-contained, testable increment that a single focused development loop can deliver. See Piotr skill for commit estimation methodology.

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | Platform does it, zero commits | RBAC role in setup.ts |
| 1 | 1 commit: config/seed only | Pipeline stages in seedDefaults |
| 2 | 1-2 commits: small gap | Widget injection + i18n |
| 3 | 2-3 commits: medium gap | Entity + CRUD route + backend page |
| 4 | 3-5 commits: large gap | Multi-entity + pages + workflow definition |
| 5 | 5+ commits or external dependency | External API + LLM pipeline |

### Per-Workflow Gap Matrix

#### WF[N]: [Name] — Total: [N] atomic commits

| Step | OM Module | Gap | Scope | Commits | Notes |
|------|-----------|-----|-------|---------|-------|
| | | | app/n8n/official-module/core-module/external | | |

> **Scope column:** Where does this commit live? `app` = our repo, `n8n` = n8n workflow, `official-module` = marketplace module, `core-module` = OM core, `external` = outside OM.
> Commits scoped `core-module` or `official-module` are platform contributions — welcome, but they need upstream PR + approval. Flag these as dependencies: your phase can't ship that commit until upstream merges. Check if UMES can extend from app side instead. See Piotr skill for details.

[Repeat per workflow]

### Gap Summary

| Workflow | Business Priority | Atomic Commits (raw) | Workaround? | Commits (effective) | Blocks ROI? |
|----------|------------------|---------------------|-------------|---------------------|-------------|
| | | | | | |

Piotr saves detailed commit plans to `apps/<app>/app-spec/piotr-notes/commits-WF<N>.md`.

#### Checklist
- [ ] Every workflow step scored in atomic commits `Mat`
- [ ] Piotr checkpoint: workflow-to-OM mapping verified — no module missed, no overengineering, commit plans saved `Piotr`

---

## 4.5 Module Architecture `Piotr`

> Consolidated view of which OM modules this app uses, how it extends them, and what new modules it creates.
> This section is derived from the per-workflow gap analysis (§4) — Piotr consolidates after checkpoint #1.

### OM Core modules used

| Module | Usage | Extension points used | Notes |
|--------|-------|----------------------|-------|
| | as-is / extend | interceptor, widget injection, defaultCustomerRoleFeatures, workflow JSON, DI override, ... | |

### Official modules (existing or proposed)

> If a gap is reusable (2+ apps would benefit), propose it as an official module instead of building it into the app.
> Proposed modules need clear boundaries: single responsibility, no app-specific domain logic.

| Module | Status | Usage | Extension points | Rationale |
|--------|--------|-------|-----------------|-----------|
| | EXISTING / PROPOSED | use / extend / create | | Why official vs app-level? Would other apps need this? |

### App modules

> App-specific domain logic that is NOT reusable across other OM apps.

| Module | Responsibility | Entities owned | Notes |
|--------|---------------|----------------|-------|
| | | | |

#### Checklist
- [ ] Every OM core module listed with explicit usage type (as-is / extend) and extension points `Piotr`
- [ ] Every listed module traces to a user story or workflow — template defaults don't count; if §2 rejects portal, don't list portal modules `Piotr`
- [ ] Every official module listed — existing ones with extension points, proposed ones with rationale `Piotr`
- [ ] Every gap scored `official-module` or `core-module` in §4 has upstream investigation (specs, issues, PRs) `Piotr`
- [ ] Reusability check: no reusable pattern hidden inside an app module — if 2+ apps would need it, propose as official module `Piotr`
- [ ] Proposed official modules have clear boundary — single responsibility, no app-specific domain logic leaked in `Piotr`
- [ ] App module count justified — if >2 app modules, explain why they can't be one `Piotr`
- [ ] Extension points to official modules documented — same UMES patterns as core (interceptors, widget injection, enrichers, DI overrides) `Piotr`
- [ ] No direct modification of core or official module code — extend only via UMES, or FLAG as upstream PR `Mat + Piotr`
- [ ] Module boundaries align with bounded context boundaries — if two modules share invariants or domain events that must be transactionally consistent, they should be one module `Vernon`

---

## 5. User Stories `Mat`

> Each story traces to a workflow step. Story = atomic action by one persona with measurable success.

### WF[N]: [Workflow Name]

**US-[N.M]** As [persona], I [action] so that [business outcome].
Success: [concrete, testable criteria]

[Repeat per story, grouped by workflow]

### Default User Stories

> Every ready app MUST include these stories. They ensure the app is testable out of the box
> without manual setup. These follow the same quality bar as domain stories: persona, action,
> measurable outcome, success criteria.

**US-0.1** As a developer evaluating this ready app, I run `yarn initialize` and get
pre-configured demo users with distinct roles so that I can log in and test every
persona's experience without manual user/role setup.
Success:
- Each role from §2 Identity Model has at least one seeded user
- All demo users share a single known password logged to console at seed time
- Login with each demo user shows only the UI and data their role permits
- Seeding is idempotent — running `yarn initialize` twice does not create duplicates
- Demo user emails follow the pattern `{role}@demo.local`

**US-0.2** As a developer evaluating this ready app, I run `yarn dev` after `yarn initialize`
and see realistic demo data (entities, pipeline deals, relationships) so that I can
understand the app's domain without reading source code.
Success:
- At least 2-3 representative entities per major domain concept
- Entities span different pipeline stages / lifecycle states
- Custom fields are populated with realistic values (not "test123")
- Demo data is visually distinguishable (names contain "Demo" marker)

#### Checklist (domain stories)
- [ ] Every story has: persona + action + measurable outcome + success criteria
- [ ] Every story traces to a workflow step — no orphan stories
- [ ] Identity checkpoint per story — User or CustomerUser? What role key?
- [ ] No weak stories — vague verbs killed: "manage", "track", "handle", "view data"

#### Checklist (default stories)
- [ ] US-0.1: Demo users seeded for every role in §2, idempotent, known password
- [ ] US-0.2: Demo data covers major domain concepts with realistic values

---

## 6. User Story Gap Analysis `Piotr`

> Map each story to OM capability. Measure in atomic commits.

| Story | Platform Match | Atomic Commits | Notes |
|-------|---------------|----------------|-------|
| | | | |

Piotr saves detailed commit plans to `apps/<app>/app-spec/piotr-notes/commits-US-<N>.md`.

#### Checklist
- [ ] Every story mapped to specific OM module/mechanism with atomic commit estimate `Mat`
- [ ] Piotr checkpoint: story-to-OM mapping verified — simplest solution for each story, commit plans saved `Piotr`

---

## 7. Phasing & Rollout `Mat`

> Phasing logic: High business priority + Low gap = ship first.
> Every phase must deliver measurable business value. If you can't state the ROI — the phase is artificial. Merge it or cut it.

### Phase [N]: [Name]

**Goal:** [What the user can do after this phase]

**Why this order:** [Business justification]

| Story | What ships | Commits |
|-------|-----------|---------|
| | | |

**Total: [N] atomic commits**
**Workaround:** [if any high-gap blocker is worked around]

**Acceptance criteria:** `Vernon writes, Mat challenges`

> **Role reversal.** Vernon (DDD) writes the acceptance criteria — domain invariants that must hold,
> aggregate consistency, event completeness, data integrity. Mat (business) challenges them —
> "is this actually needed for the business to work at this phase?" If Vernon's criterion is
> over-engineered for the current phase, Mat cuts it or defers it. If it's essential for domain
> integrity, Mat accepts it. The one who usually critiques now defends; the one who builds now pushes back.

**Domain criteria** `Vernon`:
- [ ] [Invariant that must hold after this phase — e.g., "every WIP-stamped deal has exactly one immutable timestamp"]
- [ ] [Aggregate consistency — e.g., "TierChangeProposal uniqueness: one per org per period"]
- [ ] [Event completeness — e.g., "AgencyTierChanged published on every tier approval"]
- [ ] [Data integrity — e.g., "WIC import for same org+month archives previous version"]

**Business criteria** `Mat`:
- [ ] [Testable action the primary persona can perform end-to-end]
- [ ] [Testable action another persona can perform]
- [ ] ...

**Value delivered:**
- **Business value:** [What business problem is solved that wasn't solved before this phase? Be specific.]
- **ROI metric:** [Measurable outcome. Target number. How you'd know this phase was worth building.]

**Platform ROI** (if example/reference app):
- [OM pattern demonstrated by this phase — e.g., "RBAC roles with org scoping via setup.ts"]
- [OM pattern demonstrated — e.g., "UMES API interceptor for domain event on entity change"]
- ...
- **Copy test:** [If someone copies this phase's code, what do they learn about building on OM?]

**Mat's challenges to Vernon's criteria:** [If Mat pushed back on any domain criterion — what was cut/deferred and why. If all accepted, state "all accepted."]

[Repeat per phase]

### Rollout Summary

```
Phase 1: [name]    [N] commits    [which workflows]
Phase 2: [name]    [N] commits    [which workflows]
...
                   ---------
                   [N] atomic commits total
                   [M] commits for production-ready (Phases 1-N)
```

#### Checklist
- [ ] Phases ordered by: business priority x gap score x blocker status
- [ ] Each phase delivers complete, usable increment — no half-done workflows
- [ ] Workarounds documented for high-gap blockers (gap >3)
- [ ] Total atomic commits estimated per phase `Piotr`
- [ ] Acceptance criteria per phase: Vernon wrote domain criteria, Mat wrote business criteria `Vernon + Mat`
- [ ] Mat challenged Vernon's criteria — over-engineered criteria cut or deferred, essential ones accepted `Mat`
- [ ] Business value + ROI metric stated per phase — no artificial phases
- [ ] No artificial phases — every phase delivers measurable business value. If ROI is unclear, merge with adjacent phase or cut.

---

## 8. Cross-Spec Conflicts `Mat`

| Conflict | Specs involved | Resolution |
|----------|---------------|------------|
| | | |

#### Checklist
- [ ] All related specs listed with what each contributes
- [ ] Identity model consistent across specs
- [ ] Terminology consistent — matches glossary
- [ ] Shared entities owned by one spec — if two specs reference the same entity, one is the owner
- [ ] Every entity in this table exists in §1.3 UL and is referenced by at least one user story — no phantom entities `Mat`
- [ ] Every conflict has a resolution, not "TBD"

---

## 9. Example App Quality Gate `Piotr`

> Only if this project is an example/reference app. N/A otherwise.

**Platform patterns to demonstrate:**
- [list of OM features this app showcases]

**Anti-patterns to avoid:**
- [list of what we're NOT building and why]
- Leaving scaffold boilerplate modules (`example/`, empty dirs) from `create-mercato-app` in the app
- Leaving unused modules from `create-mercato-app` template in `modules.ts` — only register modules listed in §4.5 Module Architecture. Remove corresponding imports from `layout.tsx` (e.g., AiAssistant, third-party analytics scripts)
- Copying or re-implementing OM platform helpers locally (e.g., integration test helpers, auth utilities, fixture builders) instead of importing from `@open-mercato/core/testing/integration`. If a helper doesn't exist in core — contribute it upstream, don't duplicate it in the app. Local copies drift, break on version upgrades, and teach the wrong pattern.
- Creating app-local Playwright config instead of using `mercato test` CLI and its test discovery. The CLI handles ephemeral environments, test discovery across `__integration__/` dirs, and consistent config. App-local configs bypass all of this.
- Seeding org-scoped users without `UserAcl.organizationsJson` restriction — if a role should only see its own org, the seed must create a `UserAcl` with `organizationsJson: [orgId]`. Without it, `null` = all orgs in tenant, and the org switcher exposes cross-org data.

#### Checklist
- [ ] Every piece of new code passes the "copy test" — if someone copies this, do they build ON the platform or AROUND it?
- [ ] Anti-patterns explicitly listed
- [ ] Platform features demonstrated — the app showcases what the platform can do
- [ ] Scaffold boilerplate removed — no `example` module, no empty module directories
- [ ] Integration tests import helpers from `@open-mercato/core/testing/integration` — no local copies of platform utilities
- [ ] Tests run via `mercato test` / `yarn test:integration:ephemeral` — no app-local playwright config

---

## 10. Open Questions `Mat`

| # | Question | Options | Impact | Owner | Status |
|---|----------|---------|--------|-------|--------|
| | | | | | |

#### Checklist
- [ ] Every question has: options, impact, owner, status
- [ ] No BLOCKER question unresolved before its phase starts
- [ ] Decided questions have rationale recorded

---

## Production Readiness `Mat`

> Assessed per implementation phase. Updated as phases ship.

| Workflow | Deployable | Blocker | What client would say |
|----------|-----------|---------|----------------------|
| | | | |

#### Checklist
- [ ] Each workflow assessed: deployable or not — binary, with specific blocker
- [ ] "What would client say?" test — the complaint, not the technical gap
- [ ] No workflow stops midway — if it can start but can't complete, it's worse than not existing

---

## Changelog

### [date]
- [what changed and why]

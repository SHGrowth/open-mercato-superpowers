---
name: om-implement-spec
description: Implement a spec (or selected phases) using coordinated subagents — unit tests, integration tests, docs, and code-review compliance per phase. Tracks progress by updating the spec. Triggers — "implement spec", "implement phases", "build from spec", "code the spec".
---

# Implement Spec Skill

Implements a specification (or selected phases) end-to-end using a team of coordinated subagents. Every code change MUST pass the code-review checklist before the phase is considered done.

## Pre-Flight

1. **Identify the spec**: Locate the target spec file(s) in `.ai/specs/` or `.ai/specs/enterprise/`.
2. **Load context**: Read spec fully. Read all AGENTS.md files listed in the Task Router that match the affected modules/packages.
3. **Load code-review checklist**: Read `skills/om-code-review/references/review-checklist.md` — this is the acceptance gate for every phase.
4. **Load DS references (if the spec touches UI)**: Read `om-ds-guardian/references/component-guide.md` (which primitive to pick), `page-templates.md` (canonical List/Create/Detail templates), and `token-mapping.md` (semantic tokens). All emitted UI code MUST follow these — `om-auto-review-pr` invokes `om-ds-guardian REVIEW` on every PR and will flag raw HTML controls, hardcoded colors, arbitrary text sizes, etc.
5. **Load lessons**: Read `.ai/lessons.md` for known pitfalls.
6. **Scope phases**: If the user specifies phases (e.g. "phases e-h"), filter to only those. Otherwise implement all phases sequentially.

## Extension Mode Decision (Mandatory First Step)

Before writing any code, ask the user:

> **Where should this feature live?**
>
> 1. **External extension** (npm package / standalone repo) — uses UMES extension points (widgets, events, enrichers, API interceptors) to add functionality without modifying Open Mercato core. Best for: custom business logic, vertical features, third-party integrations. Preserves upgrade path.
> 2. **Core modification** (inside `packages/` or `apps/mercato/`) — directly modifies the platform. Best for: foundational platform capabilities that all users need.

### If user chooses External Extension

- Determine if the user is working inside a `create-mercato-app` scaffolded repo or wants a standalone npm package in `packages/`.
- **Standalone npm package**: Create package under `packages/<extension-name>/` with proper `@open-mercato/<extension-name>` naming and `package.json`.
- **App-level module**: Place code in `apps/mercato/src/modules/<module>/` (or the user's app repo).
- **Maximize UMES features**: Use widget injection, event subscribers, response enrichers, API interceptors, custom fields/entities, and menu injection to achieve the goal without touching core code.
- **Never modify files in `packages/core/`, `packages/ui/`, `packages/shared/`** etc. unless absolutely necessary for a missing extension point — and if so, the missing extension point itself becomes a prerequisite spec.

### If user chooses Core Modification

Ask a confirmation:

> **Are you sure?** Modifying core means:
> - Third-party modules depending on changed surfaces may break
> - Backward compatibility contract applies (13 frozen/stable categories)
> - Users who forked or extended these files will have merge conflicts on upgrade
> - Changes require deprecation protocol if touching any contract surface
>
> Proceed with core modification?

Only continue with core changes after explicit confirmation.

## Implementation Workflow

For **each phase** in the spec, execute these steps:

### Step 1 — Plan the Phase

Read the phase from the spec. For each step within the phase:
- Identify files to create or modify
- Identify which AGENTS.md guides apply (use Task Router)
- Identify backward compatibility concerns (check `BACKWARD_COMPATIBILITY.md` contract surfaces)
- List required exports, conventions, and patterns from the relevant AGENTS.md
- Note any cross-module impacts (events, extensions, widgets, enrichers)

Present a brief plan to the user before coding.

### Step 2 — Implement

Use subagents liberally to parallelize independent work:
- **One subagent per independent file/component** when files don't depend on each other
- **Sequential execution** when there are dependencies (e.g., entity before API route before backend page)

For every piece of code, enforce these code-review rules inline:

| Area | Rule |
|------|------|
| Types | No `any` — use zod + `z.infer` |
| API routes | Export `openApi` and `metadata` with auth guards |
| Entities | Standard columns, snake_case, UUID PKs |
| Security | `findWithDecryption`, tenant scoping, zod validation |
| UI | `CrudForm`/`DataTable`, `apiCall`, `flash()`, `LoadingMessage`/`ErrorMessage`; DS primitives only (no raw `<input>`/`<select>`/`<textarea>`); semantic tokens for colors (no `text-red-*`/`bg-green-*`); typography scale (no `text-[Npx]`) — see `om-ds-guardian/references/component-guide.md` + `token-mapping.md` |
| Commands | `registerCommand`, undoable, `extractUndoPayload()` |
| Events | `createModuleEvents()` with `as const`, subscribers export `metadata` |
| i18n | `useT()` client, `resolveTranslations()` server, no hardcoded strings |
| Imports | Package-level `@open-mercato/<pkg>/...` for cross-module |
| Mutations | `useGuardedMutation` when not using CrudForm |
| Keyboard | `Cmd/Ctrl+Enter` submit, `Escape` cancel on dialogs |
| Naming | Modules plural snake_case, events `module.entity.past_tense`, features `module.action` |

### Step 3 — Unit Tests

For every new feature/function implemented in the phase:
- Create unit tests colocated with the source (e.g., `*.test.ts` or `__tests__/`)
- Test happy path + key edge cases
- Test error paths for validation and authorization
- Mock external dependencies (DI services, data engine)
- Verify tests pass: `yarn test --filter <module>`

### Step 4 — Integration Tests

If the spec defines integration test scenarios (or the phase adds API endpoints / UI flows):
- Follow the `integration-tests` skill workflow (`skills/om-integration-tests/SKILL.md`)
- Place tests in `<module>/__integration__/TC-{CATEGORY}-{XXX}.spec.ts`
- Tests MUST be self-contained: create fixtures in setup, clean up in teardown
- Tests MUST NOT rely on seeded/demo data
- Run and verify: `npx playwright test --config .ai/qa/tests/playwright.config.ts <path> --retries=0`

If the spec does not explicitly list integration scenarios but the phase adds significant API or UI behavior, propose test scenarios to the user before writing them.

### Step 5 — Documentation

For each new feature:
- Add/update locale files for new i18n keys
- If new entities with user-facing text: create `translations.ts`
- If new convention files: run `yarn generate`
- Update relevant AGENTS.md if the feature introduces new patterns developers should follow

### Step 6 — Self-Review (Code-Review Gate)

Before marking a phase complete, run a self-review against the full checklist:

1. **Architecture & Module Independence** (checklist section 1)
2. **Security & Authentication** (section 2)
3. **Data Integrity & ORM** (section 3)
4. **API Routes** (section 4) — if applicable
5. **Events** (section 5) — if applicable
6. **Commands & Undo/Redo** (section 6) — if applicable
7. **Search** (section 7) — if applicable
8. **Cache** (section 8) — if applicable
9. **Queue & Workers** (section 9) — if applicable
10. **Module Setup** (section 10) — if applicable
11. **Custom Fields** (section 11) — if applicable
12. **UI & Backend Pages** (section 12) — if applicable
13. **i18n** (section 13)
14. **Naming** (section 14)
15. **Code Quality** (section 15)
16. **Notifications** (section 16) — if applicable
17. **Widget Injection** (section 17) — if applicable
18. **Testing Coverage** (section 20)
19. **Backward Compatibility** (section 21) — always

Fix any violations before proceeding to the next phase.

### Step 7 — Update Spec with Progress

After completing each phase, update the spec file:
- Add an `## Implementation Status` section at the bottom (or update it if it exists)
- Use this format:

```markdown
## Implementation Status

| Phase | Status | Date | Notes |
|-------|--------|------|-------|
| Phase A — Foundation | Done | 2026-02-20 | All steps implemented, tests passing |
| Phase B — Menu Injection | Done | 2026-02-21 | 3/3 steps complete |
| Phase C — Events Bridge | In Progress | 2026-02-22 | Step 1-2 done, step 3 pending |
| Phase D — Enrichers | Not Started | — | — |
```

- For the current phase, mark individual steps:

```markdown
### Phase C — Detailed Progress
- [x] Step 1: Create event definitions
- [x] Step 2: Implement SSE bridge
- [ ] Step 3: Add client-side hooks
```

### Step 8 — Verification

After all targeted phases are complete:

1. **Build check**: `yarn build:packages` — must pass
2. **Lint check**: `yarn lint` — must pass
3. **Unit test check**: `yarn test` — must pass
4. **Integration test check** (with orchestration-aware routing — see below): must pass
5. **Module prepare**: `yarn generate` — if any convention files changed
6. **Migration check**: `yarn db:generate` — if any entities changed (verify generated migration is scoped correctly)

Report results to the user. If any check fails, fix and re-verify.

#### Integration test routing (v1.12.0+)

Step 4 (integration tests) has two paths depending on whether the project is opted into the `om-orchestrate` fleet:

**Singleton-detect**:
- Check if `.ai/orchestration.yml` exists AND a sentinel file (`/tmp/om-agent-e2e.pid`) names a live process AND that process has posted an e2e-related comment within the last `(e2e_poll_cadence_seconds * 4)` seconds.
- If all three are true → **enqueue** path. Stage commits, push branch, transition the linked issue from `status:coding` → `status:needs-e2e`, post the lean handoff comment, exit. The e2e singleton picks up.
- If any are false → **inline** path. Run the integration tests in-session (current pre-v1.12.0 behavior). Log a one-line note: *"E2E singleton not detected; running inline. Run `/om-orchestrate init` to enable orchestration mode."*

This is **additive**: nothing breaks for users who haven't opted into orchestration. The inline path is identical to v1.11.6 behavior. Users who DO run `/om-orchestrate init` and spawn the fleet get the singleton's benefits without modifying this skill.

The detection is intentionally lenient — three positive signals required. False positives (skipping integration tests when no singleton exists) are unacceptable; false negatives (running inline when a singleton is alive) are recoverable (the singleton sees the issue is still in `status:coding` and waits; the user can re-run after observing the inline result).

### Step 9 — Post-PR Review Gate (mandatory when a PR was opened)

Step 6's self-review is the implementer reading the checklist *to itself*. It does not substitute for an actual review pass on the resulting PR. If this implementation produced a PR (typical when dispatched via `auto-create-pr` or when the run plan opens one in its final commit), subject the PR to a real second pass before reporting complete.

`om-implement-spec` does not hold an `in-progress` lock on the PR at this point, so `auto-review-pr`'s claim check will see "not in progress, current user is the author/assignee" and claim it fresh by applying the `in-progress` label. That is expected — `auto-review-pr` owns releasing the label when it finishes, per its own step 11.

Invoke `skills/om-auto-review-pr/SKILL.md` against `{prNumber}` in autofix mode:

1. Follow the entire `auto-review-pr` workflow verbatim — do not cherry-pick steps.
2. For UI changes, the autofix loop chains `om-ds-guardian REVIEW` automatically; do not skip the DS pass on portal/backend page work.
3. If autofix opens follow-up commits, push them on the same feature branch (never rewrite history).
4. Loop until `auto-review-pr` returns a clean verdict (no actionable blockers) or the remaining findings are non-actionable (out-of-scope, false positive) and explicitly documented in the spec's `## Implementation Status` notes column.

If `auto-review-pr` cannot run (e.g., required checks not yet green, missing context), escalate: leave the spec's status as `in_progress`, stop here, and report the blocker to the user so they can decide whether to resume.

**Do not report a spec implementation complete until this step has passed.** This is the gate that catches what self-review missed: cross-file architectural concerns, security checklist items, DS-guardian findings on UI, BC concerns on contract surfaces. Two production incidents (PRM Spec #4 PR #4, PRM Spec #5 PR #5) shipped without this gate; both required cleanup loops surfaced only when the user manually asked for review. Codified 2026-05-07 as v1.11.6 — see `docs/specs/2026-05-07-implement-spec-post-pr-gate.md`.

## Subagent Strategy

| Task | Agent Type | When |
|------|-----------|------|
| Research existing patterns | Explore | Before implementing unfamiliar patterns |
| Implement independent files | Bash/general-purpose | When files have no dependencies on each other |
| Run tests | Bash | After each phase |
| Self-review | general-purpose | After each phase, against checklist |
| Integration tests | general-purpose | After phases with API/UI changes |

**Concurrency rule**: Launch parallel subagents only for truly independent work. Sequential for dependent files.

## Component Replaceability

When implementing component replacement features (as in SPEC-041h pattern):
- Every page-level component gets a unique replacement handle (auto-generated from module + path)
- Every `DataTable` instance gets a replacement handle: `data-table:<module>.<entity>`
- Every `CrudForm` instance gets a replacement handle: `crud-form:<module>.<entity>`
- Every named section (e.g., `NotesSection`, `ActivitySection`) gets a replacement handle: `section:<module>.<sectionName>`
- Document all handles in the module's AGENTS.md or a dedicated reference

## Rules

- MUST read the full spec before starting implementation
- MUST read all relevant AGENTS.md files before coding
- MUST ask the Extension Mode Decision question before writing any code
- MUST prefer UMES extension points over core modifications when extension mode is chosen
- MUST pass every applicable code-review checklist item before marking a phase done
- MUST update the spec with implementation progress after each phase
- MUST run `yarn build:packages` after final phase to verify no build breaks
- MUST create unit tests for all new behavioral code
- MUST create or propose integration tests for phases with API endpoints or UI flows
- MUST NOT skip the self-review step — it is the quality gate
- MUST NOT introduce `any` types, hardcoded strings, raw `fetch`, or other anti-patterns
- MUST follow backward compatibility rules — no breaking changes without deprecation protocol
- MUST keep subagents focused — one task per subagent, clear boundaries
- MUST report blockers to the user immediately rather than working around them silently
- MUST NOT call `ScheduleWakeup` between phases or iterations. Implementation chains in this conversation; if the user asks for unattended Ralph-style execution, hand off to `/loop 5m /auto-continue-pr <PR#>` (harness cron mode) instead. `ScheduleWakeup` with delay >270 s while a run-plan checklist has unchecked items is an anti-pattern — it inserts a 20–30 min do-nothing gap per commit. See `skills/om-cto/references/impl-orchestrator.md` § Autonomous loop policy.
- MUST NOT report a spec implementation complete until `om-auto-review-pr` has returned a clean verdict on the resulting PR (Step 9). Step 6's self-review is the implementer reading the checklist to itself and does not substitute for a real review pass. Two production incidents (PRM PR #4 + PR #5) shipped without this gate; both required user-initiated cleanup loops. See Step 9 and `docs/specs/2026-05-07-implement-spec-post-pr-gate.md`.

# Changelog

## 1.8.0

### Changed
- **3 specialist skills demoted to references under their natural parents** — they are no longer top-level user-facing entries in the skill picker, but their full content remains available and the parent skill loads the matching reference on demand:
  - `om-pre-implement-spec` → `skills/om-cto/references/pre-impl-analysis.md` (om-cto routes BC/risk-analysis prompts here)
  - `om-eject-and-customize` → `skills/om-system-extension/references/eject.md` (om-system-extension routes ejection prompts here)
  - `om-toolkit-review` → `skills/om-cto/references/toolkit-audit.md` (om-cto routes skill-corpus-audit prompts here)
- `om-cto` description widened to absorb the user trigger phrases for pre-implementation analysis (`analyze spec`, `BC analysis`, `spec readiness`, `zanim zaczniemy kodzenie`) and toolkit audit (`review skills`, `audit toolkit`, `skill health check`).
- `om-system-extension` description widened to absorb ejection trigger phrases (`eject`, `should I eject`, `customize module`, `modify core module`).
- `om-cto/SKILL.md` Task Router gained two new rows pointing at the demoted references.
- `om-system-extension/SKILL.md` §1 gained a "When UMES is insufficient" callout that loads `references/eject.md`.
- `scripts/sync-om-skills.sh` gained a `DEMOTED_SKILL_PAIRS` array and a `sync_demoted_skill()` function — upstream content for demoted skills is fetched, frontmatter is stripped, and the body is written under the parent's `references/` path. Awk frontmatter stripping recognizes only the line-1 opening `---` marker so in-body horizontal rules in markdown bodies are preserved.
- `om-pre-implement-spec` and `om-eject-and-customize` removed from `CORE_SKILL_PAIRS` and `APP_SKILL_PAIRS` respectively — future syncs flow through the new demoted path.
- Stale cross-references repaired in `om-cto/references/{advisory,spec-orchestrator,toolkit-audit}.md` — orchestrator chains now point at the new reference paths instead of the deleted top-level skills.

### Added
- `UPSTREAM.md` at the repo root — registry of which om-* skills extend, compose, or are independent of upstream skill plugins (obra/superpowers, code-review, frontend-design), what each inherits and inlines, and at which upstream version it was last reviewed. Includes a "Demoted skills" section mapping each demoted name → parent → reference path → upstream source.

### Migration notes (for plugin users)
- Prompts that previously triggered `om-pre-implement-spec`, `om-eject-and-customize`, or `om-toolkit-review` will now fire `om-cto` or `om-system-extension`, which then loads the matching reference on demand. Behavior is preserved; only the entry-point name changes.
- Direct invocation of the demoted skills via the Skill tool will no longer find them by their old names. If you scripted a workflow that calls the demoted skill directly, switch to invoking the parent and let it route via its Task Router.
- Update with `/plugins marketplace update om-superpowers`.

### Origin
- Session 2026-05-06 — discussion about reducing the user-facing skill picker surface and dynamically loading specialist tools only when needed. Validated the routing pattern against historical session data: across 9 successful om-cto fires, 6 read a single reference and 3 read two, with 77% of references staying unread per fire. Conservative demotion picked 3 skills with single-parent homes (no risk of multi-parent reachability loss) and verified-low natural top-level user-prompt frequency. om-ds-guardian was a candidate but kept top-level after discovering its multi-home wiring (build-flow validation, auto-review-pr, scaffolders).

## 1.7.2

### Changed
- `om-cto/references/advisory.md` — added structural enforcement of the existing `<HARD-GATE>`. Two additions: (1) a one-line **Enforcement** pointer right after `</HARD-GATE>` directing the agent to the new Output Contract section; (2) a new `## Output Contract` section between Phase 6 and Quality Checks. The Output Contract requires every Advisory answer to end with a `## Sources` block listing the actual tool calls (Read, gh search code, find) that back the answer — empty Sources = answer is invalid by skill contract. Bans un-denominated percentages (write `8/11 layers covered`, not `~70%`), banned hedges (`approximately`/`around`/`roughly` and Polish equivalents `około`/`mniej więcej`/`z grubsza`) before unmeasured numbers, and banned module-count estimates without enumeration. Three-box self-check before emit.

### Origin
- Session S008 (2026-05-04) — om-cto Advisory mode emitted a 4718-char ISO 9001 gap analysis with three different fabricated percentages (`~70–80%`, `0%`, `~50%`) and zero prior `Read om-reference/AGENTS.md` or `gh search code` calls. The HARD-GATE rule was correct; its enforcement was absent. I014 makes the gate structurally verifiable via the `## Sources` artifact — anyone replaying a transcript can grep for it.

## 1.7.1

### Added
- `skills/om-ds-guardian/scripts/ds-diff-check.sh` — deterministic per-file DS linter. Takes a list of changed files (args or stdin), emits `<file>:<line>:<rule-id>:<match>` findings. Pattern set kept in sync with `ds-health-check.sh`. Used as the grep-first phase of `om-auto-review-pr` step 6a.

### Changed
- `om-auto-review-pr` step 6a — flipped from LLM-only REVIEW to a two-phase additive gate. Phase 1 (`ds-diff-check.sh`, ~5s) runs first against UI-touching diff files; Phase 2 (DS Guardian REVIEW) consumes the grep findings as known-violations input and focuses on judgment cases (decoration vs status, primitive choice, missing empty/loading states, color-as-only-info, IconButton aria-label, FormField wrapping). LLM REVIEW still runs unconditionally — coverage is preserved, latency drops on the common case.

### Origin
- Session S006 (2026-05-02) — Karpathy/Musk verification of v1.7.0 absorption flagged that the deterministic gate (`ds-health-check.sh`) was demoted to a snapshot tool while LLM REVIEW carried the full enforcement burden, despite ~80% of recurring DS violations being grep-detectable. I012 promoted the deterministic floor; the additive (rather than substitutive) wiring was chosen to avoid coverage loss on judgment cases the grep can't see.

## 1.7.0

### Added
- **DS Guardian** (`om-ds-guardian`) — Design System enforcement skill absorbed from Open Mercato repo PR [#1707](https://github.com/open-mercato/open-mercato/pull/1707). Five capabilities: ANALYZE (DS violation scan), PLAN (migration plan), MIGRATE (script-based + surgical + raw-HTML→DS-primitive recipes), REVIEW (compliance review with scoring), REPORT (health metrics with delta).
- Reference: `references/component-guide.md` — when to use which DS component, API quick reference, MUST rules per primitive (Input, Select, Switch, Radio, Textarea, Tooltip, etc.) — required reading for any skill that generates UI code.
- Reference: `references/token-mapping.md` — full color/typography mapping tables, raw-HTML→DS-primitive diff recipes
- Reference: `references/page-templates.md` — canonical DS-compliant List/Create/Detail page templates — required reading for `om-module-scaffold` and `om-implement-spec`.
- Scripts: `ds-health-check.sh`, `ds-migrate-colors.sh`, `ds-migrate-typography.sh` — bundled bash codemods (also live in OM repo at `.ai/skills/ds-guardian/scripts/` since PR #1707)
- `om-auto-review-pr` step 6a: invokes DS Guardian REVIEW on UI-touching PRs (`.tsx`/`.ts` under `packages/`/`apps/` non-test paths). Severity maps to existing CRITICAL/MEDIUM/LOW pipeline. Skipped on non-UI PRs.

### Changed
- Updated plugin tagline: 20 → 21 skills
- `om-module-scaffold` step 6 (Create Backend Pages): now requires consulting `om-ds-guardian/references/page-templates.md`, `component-guide.md`, and `token-mapping.md` before emitting any page. Hard-rules listed inline (no raw HTML controls, no hardcoded status colors, no arbitrary text sizes, etc.).
- `om-implement-spec` Pre-Flight: new step 4 — load DS references when the spec touches UI. UI rule in code-review enforcement table extended with DS primitives + tokens + typography scale requirements.
- `om-backend-ui-design` and `om-code-review` collaboration table cross-references `om-ds-guardian` for design-system-specific checks (build vs. enforce split).

### Architectural decision
- **DS Guardian does not write code.** It shapes inputs (via reference docs that primary scaffolders consume) and polices outputs (via REVIEW at PR time). The original SCAFFOLD capability from PR #1707 was dropped during absorption — primary scaffolders (`om-module-scaffold`, `om-implement-spec`) own page creation and consume the DS templates as required input. Single source of truth for templates, single enforcement gate at PR time.

## 1.6.0

### Added
- Getting started guide for ideation-first workflow (no app needed to start)
- Piotr decision library — real decision patterns extracted from code reviews and architecture choices
- Personas table in Getting Started
- `app-spec/` detection for ideation-first flow
- Scaffold into same directory — app-spec stays in place

### Changed
- Restructured README for ideation-first flow
- Recommend `create-mercato-app@develop` in getting started
- Slimmed om-product-manager
- Polished plugin metadata, added `.gitignore`

### Fixed
- Broken cross-skill references
- Sync script path rewriting
- Hook completeness
- Misleading "activates all skills" wording in building section

## 1.5.0

### Added
- **User Proxy** (`om-user-proxy`) — pipeline-level decision interceptor that answers routine agent questions on the user's behalf, learning from corrections
- **Proxy gates** in om-product-manager, om-cto, om-pre-implement-spec, om-implement-spec, om-code-review — all findings/questions pass through the proxy before reaching the user
- **Piotr Decision Library** — 10 real decision patterns extracted from code reviews and architecture choices
- **Cross-story impact analysis** in om-product-manager — matrix of state changes, affected stories, conflict patterns
- **Failure and alternate paths** required for every user story — happy-path-only stories are rejected
- **Toolkit Review** (`om-toolkit-review`) — 8-dimension audit of the skill corpus for context waste, duplication, and structural drift
- Daily CI workflow for automated skill sync from upstream with auto version bump
- Getting started guide for ideation-first workflow (no app needed to start)

### Changed
- Renamed Mat persona to Marty Cagan for clarity
- Converted om-cto into lean task router (4.4 KB) with on-demand reference loading
- Removed 4 orchestration wrapper skills — Piotr dispatches base OM skills directly with dispatch context
- Replaced static platform-capabilities checklist with live discovery (AGENTS.md + `gh search code`)
- Restructured README for ideation-first flow with `app-spec/` detection

## 1.1.0

### Added
- **Spec & Implementation Orchestrator** in om-cto — autonomous spec writing and implementation coordination
- Piotr feedback triage — classifies user feedback as code bug / spec gap / business change
- 5 additional upstream OM skills: om-eject-and-customize, om-data-model-design, om-module-scaffold, om-system-extension, om-troubleshooter
- 7 framework architecture guides vendored from upstream
- Cross-skill handoffs between orchestrator and implementation skills

### Changed
- Enforced pipeline lock and auto-chain code review in implementation flow
- Session-start hook now proactively guides users through the pipeline sequence

## 1.0.0

### Added
- Initial plugin with 7 skills: om-product-manager, om-cto, om-ux, om-spec-writing, om-implement-spec, om-pre-implement-spec, om-code-review
- SessionStart hook with OM project detection
- Sync script for vendoring OM platform skills and AGENTS.md references
- Marketplace registration

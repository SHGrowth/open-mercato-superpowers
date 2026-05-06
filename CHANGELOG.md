# Changelog

## 1.11.0

### Added

- **Smart entry-point auto-detection** in `hooks/session-start`. The hook now inspects the project filesystem and injects a specific actionable recommendation into the agent's context, so the agent picks the right om-* skill to invoke even when the user prompt is vague ("continue", "finish this", "let's go", "co dalej", "kontynuuj"). Three states are detected:
  - **In-progress run** (`.ai/runs/*.md` with unchecked `- [ ]` items) → recommends `gh pr list --search "Tracking plan: <basename>"` + `om-auto-continue-pr <PR#>`. Includes plan path and unchecked-step count.
  - **Approved specs without execution plan** (specs with `Status: approved/ready/implemented`) → recommends invoking `om-cto` Implementation Orchestrator.
  - **app-spec/ phase only** → recommends `om-cto` Spec Orchestrator (if Cagan output present) or `om-product-manager` (if not).
- The recommendation includes an explicit reminder: per-atomic-commit gates (currently tests-with-code; future DS/e2e/code-review when baseline justifies) live inside the auto-* SKILL.md content and only fire when those skills are invoked. Ad-hoc `git commit` calls bypass the gate. The recommendation routes the agent through a skill where the gate is present.
- Smoke-tested across 5 scenarios: non-OM (silent), OM-no-state, in-progress plan, approved specs, app-spec only — all behave correctly.

### Why

Forensic data from a recent session (oss-prm / patryk-standalone-standalone-app, 563 records, 92 Bash calls, 6 git commits): the agent invoked `Skill` exactly once and `Agent` exactly once. The tests-with-code gate (shipped in v1.10.0) never fired — its signature `git diff --cached --name-only` + grep never appeared. Root cause: the user said "lest finish this project" (vague continuation prompt), the agent did not route to `om-auto-create-pr` / `om-auto-continue-pr` / `om-implement-spec`, and went into ad-hoc Bash mode. The gate is dead text on disk if the skill that contains it is not invoked.

This release moves entry-point selection from "agent figures it out from prose in the hook" to "hook does filesystem detection and injects a specific command." Determinism on entry; gate then fires because the skill it lives in has been invoked.

### Fixed

- `hooks/session-start` had a latent `set -e` + `pipefail` interaction with `grep`'s no-match exit code (1) that would cause the hook to exit silently when scanning `.ai/specs/` for approved specs returned zero matches. Wrapped the grep in a brace block with `|| true` to neutralize. Caught during smoke-testing of the new entry-point detection path.

### Honest scope

This is **entry-point** determinism, not **mid-session** determinism. The agent can still bypass the recommendation and run ad-hoc Bash. A `PreToolUse` hook on `git commit` (harness-level harder enforcement) is a separate piece of work — not in v1.11.0. After this release, baseline 5 sessions and measure: did the agent follow the entry-point recommendation? If <70%, the hook needs strengthening or we ship the PreToolUse Bash interceptor.

### Files touched

- `hooks/session-start` — added `most_recent_plan` / `in_progress_count` / `has_app_spec` / `approved_specs_count` detection (~30 lines), conditional `ENTRY_POINT` block (~40 lines, 0 tokens when nothing detected, ~600 tokens when most-likely-case in-progress fires).
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.0.
- `CHANGELOG.md` — this entry.

## 1.10.2

### Added

- **OM vanilla hybrid routing rule** in `hooks/session-start`. When an OM project also has `.ai/skills/` (i.e. AGENTS.md path mandates are present alongside the plugin), the SessionStart hook appends a routing-precedence section to the agent's context:
  - `.ai/skills/<name>/SKILL.md` path mandates from AGENTS.md are authoritative for synced skills.
  - Plugin om-`<name>` Skills that are synced from upstream are cross-reference only — same content, do not double-fire.
  - Plugin om-cto, om-product-manager, om-ux, om-user-proxy, om-auto-create-pr, om-auto-continue-pr are PRIMARY (custom in this repo or forked ahead of upstream).
- Smoke-tested across three scenarios: non-OM project (silent), OM project without `.ai/skills/` (no vanilla block), OM vanilla (block injected).

### Why

When a developer works inside the upstream OM clone with the plugin installed, AGENTS.md routes tasks like "implementing a spec" to `.ai/skills/implement-spec/SKILL.md` AND the plugin description for `om-implement-spec` matches the same prompt. Both fire — same content loaded twice in context, possible behavior drift between path mandate and (slightly stale) plugin sync. The routing rule tells the agent: defer to AGENTS.md path for synced skills, use plugin Skill for the 6 custom/forked ones.

### Honest caveats

- This is **soft enforcement**. Description-match still fires the plugin Skill if the model judges it hits — the rule asks the agent to skip the redundant invocation but does not block at the harness level.
- Subagents (Agent tool dispatches) may not inherit the SessionStart context. The rule reminds the orchestrator to include precedence inline when delegating to subagents.
- Custom-vs-synced skill list in the hook is hard-coded. If `scripts/sync-om-skills.sh` changes which skills are synced, the hook needs a matching update. Comment in the hook flags the maintenance burden.

### Verification plan

After v1.10.2 ships, baseline 5 sessions inside an OM-vanilla project (e.g. an `open-mercato/open-mercato` clone). Count: how often does the agent double-fire a synced skill (path mandate + plugin Skill invocation for the same task) despite the routing rule? Decision rule:

- **<10% double-fire:** hook is sufficient. Lock in.
- **10–30%:** add the precedence reminder to synced skill description fields ("if AGENTS.md path mandate exists, defer").
- **>30%:** soft enforcement isn't enough; consider stripping synced skills from the plugin entirely or thinning them to redirect stubs.

This mirrors the v1.10.0 lesson: ship the right tool for the layer, then measure rather than declare it solved.

### Files touched

- `hooks/session-start` — added `is_om_vanilla` detection (3 lines) + conditional routing block (~40 lines, ~300 tokens injected into agent context only when `.ai/skills/` is present)
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.10.2
- `CHANGELOG.md` — this entry

## 1.10.1

### Documentation

- `README.md` — added a callout under the Automation skills table describing the new tests-with-code gate (introduced in v1.10.0). Skimmers reading the README to understand `om-auto-create-pr` / `om-auto-continue-pr` behavior will now see the gate without having to dig into the CHANGELOG. Links to the spec and baseline.

No code changes. Manifest bump only so `/plugins marketplace update om-superpowers` actually picks up the README change for users on v1.10.0.

## 1.10.0

### Added

- **Tests-with-code gate at commit time.** `om-auto-create-pr` step 6 and `om-auto-continue-pr` step 4 now run a ~10-line shell check on the staged index before `git commit`. If the staged diff contains source code (`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` outside `__tests__/` and not matching `*.test.*` / `*.spec.*`) but no test files, the gate blocks the commit. The agent then either adds tests in the same commit or splits the staged set so test-bearing changes land separately. No retry counter, no `needs-human` label, no audit log — single mechanical check.

### Why narrowed from v1.9.0's four-gate proposal

v1.9.0 proposed four per-commit gates (DS, unit tests, e2e-when-applicable, code-review fast subset) and was yanked the same day after internal review surfaced two critical bugs and a process violation (see v1.9.1 entry).

The follow-up baseline (`docs/specs/2026-05-06-ralph-loop-baseline.md`, N=5 most recent `om-auto-create-pr` PRs, 15 code-bearing commits) found:

- **Tests-with-code gap:** 0/15 commits landed tests in the same commit as code. Real, measurable, mechanical to fix → ships in v1.10.0.
- **DS gap:** 0 DS issues caught at end-of-PR across the 5 PRs. Sample is backend-biased; no evidence of a gap → defer.
- **E2E gap:** 0/2 same-commit landing rate, but N=2 doesn't clear any decision threshold → defer to v1.11+ pending re-baseline of UI-heavy PRs.
- **Code-review fast subset:** ~3/15 mechanical issues catchable; 100% already auto-fixed by existing end-of-PR `om-auto-review-pr` autofix pass → drop. Marginal value over existing infrastructure.

Conclusion: only the test-coverage gap was real in this sample. v1.10.0 ships that one gate, nothing else.

### Specs

- New: `docs/specs/2026-05-06-test-coverage-at-commit.md` (the spec that drives v1.10.0).
- Evidence: `docs/specs/2026-05-06-ralph-loop-baseline.md` (the N=5 baseline that narrowed scope).
- Superseded: `docs/specs/2026-05-06-ralph-loop-per-commit-gates.md` (v1.9.0's spec, marked SUPERSEDED at the top, body preserved as historical record).

### Verification plan for v1.11.0

- Re-baseline the next 5 `om-auto-create-pr` PRs after v1.10.0 ships.
- Success criterion: same-commit test landing rate ≥ 90% (vs. 0% baseline).
- Failure criterion: rate < 50% — investigate root cause before adding more gates.
- At the same time, re-baseline UI PRs (e2e gate candidate) and end-of-PR DS findings (DS gate candidate). If either gap holds with N=5, ship in v1.11.0.

### Migration notes

- Update with `/plugins marketplace update om-superpowers`.
- The gate is mechanical: if the agent stages source code without tests, the check blocks the commit. Existing patterns where tests landed in a separate later commit will need to be revised — either include tests in the same commit, or split the staged set so test-immune changes (config, docs, package.json) land in their own commit.
- No new files were added. No `_shared/` directory. The check is inline in two SKILL.md files. If a third caller appears later, extract to a shared reference then.

### Files touched

- `skills/om-auto-create-pr/SKILL.md` — step 6 gains the gate, subsequent steps renumbered.
- `skills/om-auto-continue-pr/SKILL.md` — step 4 gains the gate, subsequent steps renumbered.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.10.0.
- `CHANGELOG.md` — this entry.
- `docs/specs/2026-05-06-test-coverage-at-commit.md` — new spec.
- `docs/specs/2026-05-06-ralph-loop-baseline.md` — baseline evidence (already shipped in v1.9.1 trail).
- `docs/specs/2026-05-06-ralph-loop-per-commit-gates.md` — v1.9.0 spec, marked SUPERSEDED at the top.

## 1.9.1

### Rollback of v1.9.0

v1.9.0 has been **yanked**. This release reverts commit `e5691c2` and restores the codebase to the v1.8.0 behavior. Users who installed v1.9.0 should update via `/plugins marketplace update om-superpowers` to receive the rollback.

### Why

Internal review of v1.9.0 surfaced two critical bugs and a process violation:

1. **Fictional invocation contracts.** `skills/_shared/per-commit-gates.md` documented `om-code-review --fast` and `om-ds-guardian` reading `/tmp/staged.diff`. Neither exists — both targets are Skills (invoked via the Skill tool), not CLIs. At runtime the agent would either fabricate an invocation or silently skip the gate. Two of three gates therefore would not run as documented.
2. **Pre-commit semantics chosen wrong for the stated use case.** OQ-1 was resolved as pre-commit (gate the staged index, leave dirty index on retry exhaustion). For dispatched / unattended runs, post-commit-with-revert gives `git log` as the audit trail and avoids the dirty-worktree-to-physically-re-attach problem. Wrong choice for the actual use case.
3. **Spec verification step skipped.** The spec's own Verification step 1 required auditing the last 5 `om-auto-create-pr` PRs to baseline what gates would catch at commit time vs end-of-PR. That audit was not run before implementation. There was no evidence the per-commit gate solves a failure mode the existing end-of-PR pass doesn't already catch.

### What's still in flight

The work is not abandoned — only rolled back. The plan, in order:

1. Run the L93 baseline (5 most recent `om-auto-create-pr` PRs, per-commit gate-coverage analysis with numbers).
2. Branch on the baseline data: ship gates, ship them partially, or abandon.
3. If shipping: rewrite `_shared/per-commit-gates.md` with real Skill-tool invocations, replace per-commit `om-code-review` with a focused inline subagent (security + arch only), flip OQ-1 to post-commit-with-revert, collapse work-commit + Progress-flip + Gate-log into one commit per Step. Ship as v1.10.0.

### Migration notes

- If you installed v1.9.0, run `/plugins marketplace update om-superpowers` to pull v1.9.1 (rollback). Your local plugin will return to v1.8.0 behavior.
- The v1.9.0 git tag is preserved for history. Its GitHub Release body is marked YANKED.
- No data or PR state from any prior auto-create-pr / auto-continue-pr run is affected — the rollback only changes which version of the skill drives future runs.

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

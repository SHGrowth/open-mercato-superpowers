# Changelog

## 1.11.6

### Added — om-implement-spec post-PR review gate

**Triggered by PRM PR #4 + PR #5 (consecutive incidents, same shape).** Two autonomous spec implementations stopped at "PR opened" without invoking any real code-review pass. PR #4 (Spec #4 WIC ingestion) shipped a "merge-ready" comment; the user caught it manually with *"we havent closed this in clean way, have we run tests, ui tests, design system review code review?"* — triggered 5 cleanup iterations. PR #5 (Spec #5 RFP broadcast/response) repeated the exact same gap one day later: 14 commits, run plan C5 ran typecheck + jest + integration + opened the PR + posted "Spec #5 shipped end-to-end" + went idle. **Zero `om-auto-review-pr` invocation. Zero `om-ds-guardian REVIEW` on the new portal pages. Zero security checklist pass.** The fix from PR #4 lived only in the user's session memory and was never encoded into om-superpowers.

The gap: `om-auto-create-pr` (Step 11) and `om-auto-continue-pr` (Step 7) both run `om-auto-review-pr` in autofix loop until clean. **`om-implement-spec` doesn't.** Its Step 6 ("Self-Review") is the implementer reading the checklist *to itself*, which catches the rules the implementer was already trying to follow but does NOT catch cross-file architectural concerns, security checklist items needing fresh eyes (orgId scoping, tenant isolation, ACL guards), DS-Guardian findings, BC concerns on contract surfaces, or test-coverage gates that fire at commit boundaries. The orchestrator (`impl-orchestrator.md` Step 2) named "Code review: passed" as a gate but didn't actually invoke `om-auto-review-pr` — it left that to the implementer, which didn't do it. Net cost: every `om-implement-spec` run produced a PR that *looked* complete but bypassed the same review pass every other PR-producing skill enforces.

v1.11.6 closes the gap with the same three-layer doc-only shape as v1.11.5. No enforcement hook (rejected — false-positive risk on legitimate "stopped early because user interrupted" or "stopped because real blocker" cases, see spec § Why doc-only, no hook). See `docs/specs/2026-05-07-implement-spec-post-pr-gate.md` for the full forensic and rationale.

#### Layer 1 — `skills/om-implement-spec/SKILL.md` new Step 9 "Post-PR Review Gate"

Inserted after Step 8 Verification, before Subagent Strategy. Mirrors the language from `om-auto-create-pr` Step 11 and `om-auto-continue-pr` Step 7. Mandates: invoke `auto-review-pr <PR#>` in autofix mode against the resulting PR; chain `om-ds-guardian REVIEW` for UI changes; loop until clean verdict or non-actionable findings explicitly documented in the spec's `## Implementation Status` notes column; if `auto-review-pr` cannot run, escalate by leaving the spec status as `in_progress` and reporting the blocker to the user. **Closing line: do not report a spec implementation complete until this step has passed.**

#### Layer 2 — `skills/om-cto/references/impl-orchestrator.md` Step 2 "Verify completion"

The "Code review: passed" bullet was a passive checkbox the implementer self-attested. Now explicitly says `om-auto-review-pr <PR#>` must be invoked and return a clean verdict, autofix loop applied, all Critical/High findings fixed, DS-Guardian REVIEW chained for any UI changes. Notes that as of v1.11.6, `om-implement-spec` Step 9 enforces this; Piotr verifies it actually ran and passed before checkpointing.

#### Layer 3 — `om-implement-spec` Rules block one-liner

Added: *"MUST NOT report a spec implementation complete until `om-auto-review-pr` has returned a clean verdict on the resulting PR (Step 9). Step 6's self-review is the implementer reading the checklist to itself and does not substitute for a real review pass. Two production incidents (PRM PR #4 + PR #5) shipped without this gate."*

### Files touched

- `README.md` — added v1.11.6 callout under the Implementation skills table explaining the new Step 9 gate.
- `skills/om-implement-spec/SKILL.md` — new Step 9 + Rules one-liner.
- `skills/om-cto/references/impl-orchestrator.md` — operationalized "Code review: passed" bullet in Step 2.
- `docs/specs/2026-05-07-implement-spec-post-pr-gate.md` — new forensic + rationale + verification criteria + why-no-hook.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.6.
- `CHANGELOG.md` — this entry.

### Process notes (lessons)

- The fix that surfaced from PR #4's "we haven't closed this in clean way" correction lived only in the user's session memory. The next spec implementation (PR #5) walked into the same gap one day later. **One-time corrections in conversation do not persist; only doc/skill/memory layer changes do.** This release codifies the rule so it survives the next session.
- Two consecutive incidents with the same shape is the threshold for a v1.X release in this project. v1.11.5 (the /loop self-pace fix) and v1.11.6 (this fix) both ship from the same patryk-standalone forensic vein. If v1.11.7 emerges from the same source, it will likely be a hook escalation — the doc layer is getting its second fair trial.
- Saved as a feedback memory: `om-implement-spec` does not invoke `om-auto-review-pr` in versions ≤ v1.11.5; future sessions in om-superpowers context need to know this gap closed in v1.11.6 and remember to run the review pass themselves if they encounter pre-v1.11.6 behavior.

## 1.11.5

### Added — autonomous loop policy

**Triggered by patryk-standalone forensic.** A long-running orchestrated session (Spec #5: RFP broadcast/response, branch `feat/prm-spec-05-rfp-broadcast-response`) was told mid-run to "do that in our ralph loop approach" and invoked the harness `/loop` skill *self-paced* (no interval). That mode wires the agent to call `ScheduleWakeup` between iterations, whose tool-description default for "idle ticks" is 1200–1800 s. The agent dutifully picked 1200 s, then 1500 s, while a run plan with C1.10/C2.x/C3a–d/C4/C5 unchecked sat right next to it. Each "tick" inserted a 20–30 min do-nothing gap per commit, and at iteration 4 the agent wrote a `ScheduleWakeup` reason — *"cache-friendly idle window keeps prompt cache warm across iterations"* — that contradicts the tool's own first sentence (cache TTL is 300 s, not 1500 s).

The `/loop` skill is harness-owned and we can't patch its tooltip. What om-superpowers controls is the dispatch context — what an agent reads when entering autonomous Ralph mode via `om-cto` / `om-implement-spec` / `om-auto-continue-pr`. Before this release, those skills were silent on `/loop` mode selection; the agent had no policy to anchor against. v1.11.5 closes that gap with a three-layer doc-only policy. No enforcement hook (rejected — false-positive risk on legitimate polling-mode wake-ups). See `docs/specs/2026-05-07-autonomous-loop-policy.md` for the full forensic and rationale.

#### Layer 1 — `README.md` "Autonomous Ralph-style runs" anti-pattern callout

Adds an explicit **do NOT use `/loop` self-paced for chained autonomous coding** callout under the existing v1.11.0 cron-mode example. Names the two correct patterns: `/loop 5m /auto-continue-pr <PR#>` (cron mode, fresh context per turn) or a single long conversation that chains checklist items without sleeping. Calls out the cache-TTL contradiction so users who get burned by it again can recognize the failure mode.

#### Layer 2 — `skills/om-cto/references/impl-orchestrator.md` § Autonomous loop policy

Adds a three-paragraph subsection right after "Dispatch Context: Implementation." Says implementation runs in this conversation, chained; for unattended runs, use cron-mode `/loop` or a single long Task agent. Explicitly forbids `/loop` self-paced for chained autonomous coding and explains why (idle-tick default doesn't fit queued work). Cites the patryk forensic.

#### Layer 3 — `om-implement-spec` and `om-auto-continue-pr` Rules one-liner

Each skill's Rules section now includes: *"MUST NOT call `ScheduleWakeup` between phases / iterations / checklist items. … delay >270 s while a run-plan checklist has unchecked items is an anti-pattern."* Cross-references the orchestrator policy. Catches the case where the agent never reads the orchestrator reference but does reach the SKILL.md Rules block.

### Files touched

- `README.md` — added v1.11.5 anti-pattern callout under "Autonomous Ralph-style runs."
- `skills/om-cto/references/impl-orchestrator.md` — new "Autonomous loop policy" subsection after "Dispatch Context: Implementation."
- `skills/om-implement-spec/SKILL.md` — appended `ScheduleWakeup` rule to Rules section.
- `skills/om-auto-continue-pr/SKILL.md` — appended `ScheduleWakeup` rule to Rules section.
- `docs/specs/2026-05-07-autonomous-loop-policy.md` — new forensic + spec.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.5.
- `CHANGELOG.md` — this entry.

### Process notes (lessons)

- The `/loop` skill is shipped by the harness, not by om-superpowers. We can't patch its tooltip default of 1200–1800 s. Anchoring policy in our own dispatch contexts and skill Rules is the only lever we have when the agent reaches for the wrong harness mode.
- Saved as a feedback memory: `/loop` self-pace is for polling external signals; for chained autonomous coding, use cron mode (`/loop 5m …`) or a single long conversation. Future sessions in om-superpowers context shouldn't re-derive this from scratch.

## 1.11.4

### Documentation

- `README.md` — added two callouts under the Automation skills table for behavior changes that shipped in v1.11.2 (auto-review-pr autofix gate) and v1.11.3 (duplicate-work prevention via `gh pr list` keyword overlap check). Skimmers reading the README to understand `om-auto-create-pr` / `om-auto-continue-pr` / `om-auto-review-pr` will now see all three layers without digging into the CHANGELOG.

### Removed

- **All Polish-language text removed from active skills, hooks, and references.** Owner directive: skills/docs are English-only. Three places had active Polish:
  - `hooks/session-start` — removed `"co dalej"` and `"kontynuuj"` from the vague-prompt example list in the entry-point block. Replaced with English equivalents (`"what's next"`, `"resume"`).
  - `skills/om-cto/SKILL.md` — removed the `"zanim zaczniemy kodzenie"` trigger phrase from the description frontmatter. The English equivalent (`"before we start coding"`) remains.
  - `skills/om-cto/references/advisory.md` — replaced the Polish-equivalents list (`"około"`, `"mniej więcej"`, `"z grubsza"`) for hedge-word ban with the language-agnostic phrasing `"or any equivalent hedge in any language"`. Same semantic ban, no Polish strings.

CHANGELOG entries from prior releases (v1.7.2, v1.8.0, v1.11.0) that mention Polish phrases as historical context are preserved as-is — historical record should not be rewritten.

### Process notes (lessons)

- v1.11.3 shipped a behavior change without a matching README callout — same gap as v1.10.0 → v1.10.1. Caught only when explicitly asked to audit "shipped in pro way?" Saved as a feedback memory: README updates for behavior changes belong in the SAME commit as the behavior, not deferred.
- Polish trigger phrases had crept in across three releases (v1.7.2, v1.8.0, v1.11.0) without a written rule prohibiting them. Owner directive on 2026-05-07 establishes the rule going forward: skills/docs are English-only. Saved as a feedback memory.

### Files touched

- `README.md` — added two callouts under the Automation skills table.
- `hooks/session-start` — removed two Polish phrases from the entry-point block's vague-prompt example list.
- `skills/om-cto/SKILL.md` — removed one Polish trigger phrase from the description frontmatter.
- `skills/om-cto/references/advisory.md` — replaced Polish-equivalents list with language-agnostic phrasing.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.4.
- `CHANGELOG.md` — this entry.

## 1.11.3

### Added — duplicate-work prevention (two layers)

**Triggered by patryk-standalone forensic.** A session ran "continue our auto development" and over 36 minutes created `feat/prm-spec-04-wic-ingestion` with 7 commits re-implementing WIC ingestion under "T4" labels — while PR #4 (`feat/prm-t3-wic-ingestion`, "T3: PRM WIC ingestion (Spec #4)") was already open with the exact same scope. The agent had run `gh pr view 4` and seen the existing tracking plan. It proceeded anyway. The local `.ai/runs/` scan only saw plans on the current branch — PR #4's plan lived on its own feature branch and was invisible to the v1.11.0 entry-point detection.

This release closes both gaps with two complementary layers:

#### Layer 1 — `hooks/session-start`: open-PR tracking-plan scan (soft surfacing)

After the existing local `.ai/runs/` scan, the SessionStart hook now runs:

```bash
gh pr list --state open --json number,headRefName,body --limit 30 \
  | python3 [extract Tracking plan: <path> from each PR body]
```

When matches are found, an "In-Flight Work Detected Elsewhere" block is injected into the agent's context with the canonical list of tracking plans backed by open PRs, plus a hard rule: if the incoming task overlaps, STOP and run `om-auto-continue-pr <PR#>` instead of forking. Tolerates `gh` unavailability (skips silently). One network call (~500ms), additive to the v1.11.0 entry-point block.

#### Layer 2 — `om-auto-create-pr` step 0: keyword-overlap check (hard enforcement)

Before claiming the slug, step 0 now extracts keywords from the brief (Spec numbers, module names, feature words) and runs `gh pr list --search "<keywords> in:title,body"`. If any open PR matches:

- **STOP.** Surface the matched PR(s) to the user via `AskUserQuestion`.
- Wait for explicit choice: `resume` (hand off to `auto-continue-pr`), `parallel` (confirm intentional fork), or `abort`.
- Never silently fork against an open PR for the same Spec / module / feature.

Hard enforcement because the patryk-standalone forensic showed the agent had `gh pr view 4` data and ignored it. Surfacing alone wasn't enough; the create-pr step needs to halt and ask.

A new entry was added to the skill's Rules section locking in the discipline. `gh` unavailability falls back to the SessionStart hook's soft layer.

### Why two layers, not one

The SessionStart hook is informational — it makes the right answer obvious in the agent's context. It does NOT prevent the agent from creating a new plan if it judges (incorrectly) that the work is parallel. The auto-create-pr step 0 check makes the wrong answer expensive: the agent has to either match keywords differently (hard) or affirmatively confirm parallel work to the user. Two layers because a single soft surfacing layer empirically does not stop the failure.

### Smoke-tested

- Non-OM directory: hook returns `{}` ✓
- OM project, no open PRs: no In-Flight block ✓
- OM project with open PR carrying `Tracking plan:` line in body (verified against patryk-standalone): block correctly lists `PR #4 (feat/prm-t3-wic-ingestion): .ai/runs/2026-05-06-prm-t3-wic-ingestion.md` ✓

### Honest limits

- Hook scan caps at 30 open PRs (`--limit 30`) — repos with hundreds of open PRs may need the limit raised.
- Keyword extraction in auto-create-pr step 0 uses a project-vocabulary regex that needs tuning per repo (Spec numbering format, module names). The example regex matches OM projects' patterns; downstream apps may need to adjust.
- Both layers depend on PR bodies actually containing the `Tracking plan:` line — auto-create-pr writes this by default, but manually-created PRs do not. Cross-branch git scan (find `.ai/runs/` files in branches without an open PR) is deferred to a future release if the v1.11.3 baseline shows it's needed.
- Network failure / no `gh` auth: both layers degrade gracefully (skip the scan, do not block the session). The local-only fallback is the v1.11.0 entry-point detection.

### Files touched

- `hooks/session-start` — added `open_pr_plans` scan via `gh pr list` + python regex extraction; conditional "In-Flight Work Detected Elsewhere" block appended to OM_CONTEXT when matches are found.
- `skills/om-auto-create-pr/SKILL.md` — added "Duplicate-PR keyword check" sub-section in step 0 (~30 lines) + one new entry in the Rules section.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.3.
- `CHANGELOG.md` — this entry.

## 1.11.2

### Fixed

- **`om-auto-review-pr` autofix commits now run the tests-with-code gate.** The gate was added to `om-auto-create-pr` step 6 and `om-auto-continue-pr` step 4 in v1.10.0 but NOT to `om-auto-review-pr`'s autofix loop. Forensic check of a recent session (patryk-standalone, PR #4 autofix pass) showed an autofix commit titled `fix(prm): tenant-scope all WIC query paths + migrate to findWithDecryption` landed code-bearing changes without test files in the same commit, and the gate signature `git diff --cached --name-only` never appeared. The gate is now in `om-auto-review-pr` §10 as a "Tests-with-code gate (mandatory before every autofix commit)" sub-section, with the same shell block and same exemptions as the other two auto-* skills, plus a new entry in the Rules list.
- **`scripts/sync-om-skills.sh` retroactively corrected.** v1.10.0's CHANGELOG claimed `om-auto-create-pr` and `om-auto-continue-pr` were removed from `CORE_SKILL_PAIRS`, but the actual v1.10.0 commit (`5135095`) shipped without that file change. Both skills have been at risk of CI sync overwrite since v1.10.0 — every daily sync run could have wiped the gate edits. v1.11.2 removes all three auto-* skills (including the newly-forked auto-review-pr) from `CORE_SKILL_PAIRS` and updates the header comment to reflect the actual fork timeline.
- **`README.md` Custom vs Synced table** was also stale relative to v1.10.0's claims. Now correctly lists all three auto-* skills as Custom and explains the fork timeline.

### Why this gap existed

The tests-with-code gate is a per-skill copy, not a shared layer. v1.10.0's spec was scoped to "skills produced by `om-auto-create-pr` and resumed by `om-auto-continue-pr`" — `om-auto-review-pr`'s autofix loop is a third entry point that also produces commits, and v1.10.0's spec didn't enumerate it. The forensic on PR #4's autofix surfaced this as a real coverage hole, not a hypothetical one.

This is a coverage-completeness fix, not a new feature. Same gate, same shell block, third invocation site.

### Files touched

- `skills/om-auto-review-pr/SKILL.md` — added a "Tests-with-code gate (mandatory before every autofix commit)" sub-section in §10 (the autofix loop) plus one new entry in the §Rules section.
- `scripts/sync-om-skills.sh` — removed all three auto-* skills from `CORE_SKILL_PAIRS`, corrected header comment to reflect actual fork timeline.
- `README.md` — Custom vs Synced table now lists all three auto-* skills as Custom; added paragraph explaining the fork timeline (v1.10.0 + v1.11.2).
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.11.2.
- `CHANGELOG.md` — this entry.

### Honest note

Two of the three changes in this release (sync-script removal, README table) are corrections of oversights from v1.10.0, not new work. v1.10.0's CHANGELOG documented these as "landed" when they had not actually been committed. Caught only because v1.11.2 was investigating a related issue (the auto-review-pr gap). Lesson saved to memory: verify CHANGELOG claims against the actual diff before tagging.

## 1.11.1

### Documentation

- `README.md` — added two callouts under the Automation skills table: (1) brief note on the v1.11.0 entry-point auto-detection, (2) **Autonomous Ralph-style runs** section explaining how to compose Claude Code's harness `/loop` skill with `om-auto-continue-pr` for unattended execution. No custom bash wrapper is shipped — the harness's `/loop` already does what Ralph's `for` loop does, and v1.11.0's SessionStart hook makes each cold iteration self-orient toward the in-progress plan.

No behavior change. Manifest bump only so `/plugins marketplace update om-superpowers` actually picks up the README for users on v1.11.0.

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

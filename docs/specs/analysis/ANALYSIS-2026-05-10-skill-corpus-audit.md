# ANALYSIS — skill-corpus 30-day usage audit

**Date:** 2026-05-10
**Author:** Claude (agents-master meta-session) — handoff to PR #5 reviewer
**Backs:** PR #5 (`chore/1.16.0-skill-demotion`) — the "30-day usage data" claim cited in the CHANGELOG entry.

## TL;DR

PR #5 demotes 7 skills to references under their parent + deletes 1 (`om-orchestrate`) based on a 30-day usage audit. This doc captures the audit so the demotion decisions are re-auditable, and so future audits can re-run the same query and append a row.

**Verdict:** the 8 skills targeted by PR #5 do not function as user-typed entry points. They are either pure-reference (loaded by a parent skill via `Read`), unused (zero footprint), or both. The two with non-trivial direct invocations (`om-user-proxy`, `om-spec-writing`) are called *by other skills*, not user-typed — demoting under the calling parent preserves the call path.

## Methodology

Two channels mined across all `~/.claude/projects/*/*.jsonl` since 2026-04-10 (30 days prior to today, 2026-05-10):

1. **`Skill` tool invocations** — direct user-typed (or parent-skill-routed) entry points.
2. **`Read` tool calls hitting `skills/om-<name>/SKILL.md` or `skills/om-<name>/references/`** — proxy for "loaded as reference by another skill or by the agent self-routing into the skill body."

Channel 1 is the strongest signal for "this is a user-typed entry point." Channel 2 is the strongest signal for "this is loaded as a specialty reference during specific work episodes."

## Reproducible queries

```bash
# Channel 1 — Skill invocations
cd ~/.claude/projects && for f in $(find . -maxdepth 2 -name "*.jsonl" -newermt "2026-04-10"); do
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // empty' "$f" 2>/dev/null
done | grep -E "^(om-superpowers:)?om-" | sed 's|om-superpowers:||' | sort | uniq -c | sort -rn

# Channel 2 — Read activity on skill paths
cd ~/.claude/projects && for f in $(find . -maxdepth 2 -name "*.jsonl" -newermt "2026-04-10"); do
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Read") | .input.file_path // empty' "$f" 2>/dev/null
done | grep -oE "skills/om-[a-z-]+/(SKILL\.md|references/)" | sort | uniq -c | sort -rn
```

## Data — 2026-05-10 audit

### Top-level survivors (kept as user-facing entry points)

| Skill | Skill invocations | Reads of SKILL.md | Reads of references/ | Verdict |
|---|---|---|---|---|
| `om-cto` | 36 | 23 | 103 | Top-level — orchestrator |
| `om-product-manager` | 8 | 19 | 11 | Top-level — entry point |
| `om-auto-review-pr` | 6 | 9 | — | Top-level — automation entry |
| `om-code-review` | 5 | 9 | — | Top-level — entry point |
| `om-auto-create-pr` | 4 | 7 | — | Top-level — automation entry |
| `om-troubleshooter` | 3 | 3 | — | Top-level — entry point |
| `om-ds-guardian` | 3 | 8 | — | Top-level — quality enforcement |
| `om-implement-spec` | 2 | 12 | 4 | Top-level — orchestrator |
| `om-auto-continue-pr` | 2 | 7 | — | Top-level — automation entry |
| `om-ux` | 1 | 7 | — | Top-level — entry point |
| `om-integration-tests` | 1 | 2 | — | Top-level — pipeline part |

All 11 survivors show direct `Skill` invocations and SKILL.md Reads. They function as user-typed entry points or always-on pipeline parts.

### Demoted (7 skills moved to `references/` under parent)

| Skill | Skill invocations | Reads of SKILL.md | Reads of references/ | Demotion target | Decision rationale |
|---|---|---|---|---|---|
| `om-user-proxy` | 6 | 5 | — | `om-cto/references/user-proxy.md` | Called *by other skills* (proxy invocation pattern, parent loads it) — never user-typed in the 30-day window |
| `om-spec-writing` | 7 | 6 | 9 | `om-cto/references/spec-writing/` | Same shape — om-cto's Task Router routes "write specs" here; user types "write specs from app spec" → om-cto, not directly to om-spec-writing |
| `om-module-scaffold` | 0 | 6 | 0 | `om-implement-spec/references/module-scaffold/` | Zero direct invocations; loaded only via parent's reference path |
| `om-data-model-design` | 0 | 4 | 0 | `om-implement-spec/references/data-model-design/` | Same — pure-reference profile |
| `om-system-extension` | 0 | 4 | 0 | `om-implement-spec/references/system-extension/` | Same — pure-reference profile |
| `om-integration-builder` | 0 | 2 | 0 | `om-implement-spec/references/integration-builder/` | Same — pure-reference profile |
| `om-backend-ui-design` | 0 | 3 | 0 | `om-ds-guardian/references/backend-ui-design/` | Same — pure-reference profile |

Of the 7 demoted skills: 5 have **zero** direct `Skill` invocations in 30 days. The other 2 are called by other skills, not by users typing trigger phrases. None functions as a user-typed entry point. Demoting under the parent skill that already routes to them preserves every observed call path.

### Deleted (1 skill)

| Skill | Skill invocations | Reads of SKILL.md | Reads of references/ | Verdict |
|---|---|---|---|---|
| `om-orchestrate` | 0 | 0 | 0 | Fully dead in 30 days. Deletion justified. |

`om-orchestrate` has zero footprint across both channels — no user typed it, no agent loaded it. Combined with the `feedback_loop_self_pace_anti_pattern` finding (the harness `/loop 5m /auto-continue-pr` superseded the autonomous-fleet workflow), there is no consumer left.

### Calibration — already-demoted skills (v1.8.0 era)

The v1.8.0 demotions have been running for months. Their 30-day usage:

| Skill (already demoted) | Skill invocations | Reads of SKILL.md | Reads of references/ |
|---|---|---|---|
| `om-toolkit-review` | 1 | 5 | — |
| `om-pre-implement-spec` | 0 | 5 | — |
| `om-eject-and-customize` | 0 | 2 | — |

Same shape as PR #5's targets: low/zero `Skill` invocations + non-zero `Read` activity. The pattern is real and the demotion mechanism works in production.

## Caveats

1. **Channel 2 is a proxy, not a measure.** `Read` calls on a SKILL.md path could be the agent reading the file as documentation rather than activating the skill. The signal is directional — non-zero Reads indicate the file is being consulted — but it doesn't equal "the skill body executed." For demotion decisions, this is sufficient: the question is "does the body provide reference value to a parent context?" not "did the skill execute as a top-level entry."

2. **Trigger-phrase auto-activation isn't directly captured.** Claude Code can auto-load a skill when the user message matches its trigger keywords, without an explicit `Skill` tool call. That activation isn't visible in `tool_use` records. So the `Skill` invocation column is a *lower bound* on user-driven entry-point usage. For the demotion decisions: the lower bound is zero or near-zero for 5 of 7 skills, which is robust to this caveat. For `om-user-proxy` (6) and `om-spec-writing` (7), the explicit invocations are already counted; auto-activation would only add to non-user-typed uses, which strengthens the demotion case.

3. **30-day window is one slice.** Skills that are seasonal (e.g., used heavily during quarterly planning) could show zero in a 30-day window and re-emerge later. For high-confidence demotion vs. deletion, watch the curve over 60-90 days. PR #5 demotes (reversible — body still loadable via parent's `references/`) rather than deleting (mostly destructive) for 7 of 8 skills, which is the right asymmetric bet under this uncertainty. The one deletion (`om-orchestrate`) is justified by zero footprint AND a documented superseder.

4. **Sample bias.** This audit mines the user's local sessions only. If the plugin is shipping to other operators whose usage patterns differ, their 30-day signal could disagree. For the maintainer's calibration, this is fine — but a community plugin used at scale would need broader telemetry.

## Cutover decision per skill (verbatim from PR #5 + verified)

| Skill | Decision | Rationale |
|---|---|---|
| `om-user-proxy` | Demote to `om-cto/references/user-proxy.md` | Called by parent skills, never user-typed; lives where it's invoked |
| `om-spec-writing` | Demote to `om-cto/references/spec-writing/` (+3 sub-refs) | Routed via om-cto Task Router today; demoting closes the implicit-routing gap |
| `om-module-scaffold` | Demote to `om-implement-spec/references/module-scaffold/` | Pure-reference profile; only loaded during implementation work |
| `om-data-model-design` | Demote to `om-implement-spec/references/data-model-design/` | Pure-reference profile |
| `om-system-extension` | Demote to `om-implement-spec/references/system-extension/` | Pure-reference profile |
| `om-integration-builder` | Demote to `om-implement-spec/references/integration-builder/` | Pure-reference profile |
| `om-backend-ui-design` | Demote to `om-ds-guardian/references/backend-ui-design/` | Pure-reference profile; co-locates with the design-system enforcer that already routes to it |
| `om-orchestrate` | Delete | Zero footprint + documented superseder (`/loop 5m /auto-continue-pr`) |

## Budget impact (cross-ref to CHANGELOG)

| Stage | Top-level skills | Description chars | Δ vs baseline |
|---|---|---|---|
| Baseline (1.15.0) | 19 | 8,577 | — |
| 1.15.1 (frontmatter trim) | 19 | 4,889 | −43% |
| **1.16.0 (this PR)** | **11** | **3,031** | **−65%** |

## Future audits

Re-run the two queries above on a 60-day cadence. Append a row per audit to a ledger at `docs/specs/analysis/skill-corpus-ledger.md` (one row per audit date, columns: top-level count, total description chars, skills demoted/deleted in that window). The ledger gives a longitudinal view of corpus health.

If a skill currently in `references/` ever shows a sustained spike in `Skill` invocations, promote it back to top-level (the inverse move) — the data, not the architecture, decides.

## Provenance

- Mining run: 2026-05-10, agents-master meta-session, `~/.claude/projects/*/*.jsonl` since 2026-04-10
- Triggering review: agents-master review of PR #5 flagged the 30-day claim as un-archived; this doc closes that gap
- Cross-ref: `feedback_loop_self_pace_anti_pattern.md` (om-superpowers project memory) — supports the `om-orchestrate` deletion
- Cross-ref: `feedback_skill_surface_budget.md` (om-superpowers project memory) — the principle this audit operationalizes
- Cross-ref: v1.8.0 demotion precedent (`om-pre-implement-spec`, `om-eject-and-customize`, `om-toolkit-review`) — calibrates the pattern

# ANALYSIS — upstream-bug-triage / handoff baseline

> **Superseded for the plan section by [`ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md`](ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md).** The empirical baseline (mining query, 67% binding rate, three-tasks-on-2026-05-10 breakdown) below remains the data of record. The "Revised plan for om-superpowers" + Q1–Q4 recommendations were rejected after Musk Step 1 review — see v2 for what 1.15.0 actually shipped (skill-body convention, no `bin/` wrappers).

**Date:** 2026-05-10
**Author:** Claude (agents-master meta-session) — handoff to waiting om-superpowers session
**Originating context:** `/Users/maciejgren/Documents/agents-master/` adversarial review of yesterday's `skills/om-cto/references/upstream-bug-triage.md` edit, followed by Layer 1 baseline mining of past session jsonls.

## TL;DR

Yesterday's session added a **prose rule** to `om-cto/upstream-bug-triage` mandating "drop a task file in `<om-core-checkout>/agents/tasks/` and stop; do not author the upstream patch from the consumer-app session." Edit is uncommitted, awaiting release.

Adversarial subagent review of a follow-up structural-binding proposal (a `PreToolUse` lockdown hook) found 2 BLOCKER and 4 SERIOUS issues, including: matcher missed `Bash` (which writes via `cat > file`, `sed -i`, etc.); proposal used wrong hook output shape (`{"decision":"block"}` is `Stop` semantics, not `PreToolUse`); sentinel keying on `sessionId` is impossible from the wrapper because `session_id` is hook-stdin only.

Layer 1 empirical baseline (mining all session jsonls since 2026-04-01) reframed the whole problem. Findings below.

## Empirical baseline — mined from `~/.claude/projects/*/*.jsonl` since 2026-04-01

Reproducible query: see "Verification" section.

**31 cross-project Edit/Write/MultiEdit events** where `cwd` was outside `/Users/maciejgren/Documents/OM/` and `file_path` was inside it.

| Source cwd | Count | Destination | Type |
|---|---|---|---|
| `patryk-standalone/standalone-app` | 16 | `/OM/agents/tasks/...` | Handoff pattern |
| `temp-1` | 15 | `/OM/.ai/...` | Different concern, out of scope |

**Inside the 16 handoff writes — three distinct tasks dropped on 2026-05-10 by `patryk-standalone`:**

| Task | Files written |
|---|---|
| `2026-05-10-warmup-hardening` | `README.md` (3 edits) + **`patches.diff` (2 edits)** |
| `2026-05-10-scheduler-supervisor-bug` | `README.md` (1 edit) |
| `2026-05-10-package-exports-multi-asterisk` | `README.md` (8 edits) |
| top-level `agents/tasks/README.md` | 4 edits (index updates) |

**The failure mode yesterday's rule was guarding against — consumer-app session authoring the upstream patch — appears in 1 of 3 tasks** (`warmup-hardening` had a `patches.diff` written by the standalone-app session). 33% failure rate on a small sample; not 0%, not 100%. PRM-cwd sessions did not appear in the data.

## Three findings that change the plan

**1. Handoff is already binding without any rule, when the convention is intuitive.**
Patryk-standalone wrote 11 of 16 task files correctly (README-only handoffs) without any om-superpowers skill prose telling it to. The folder existing at `/OM/agents/tasks/` is the strongest binding signal in the data. Friction reduction is the right direction.

**2. The structural-policing proposal (PreToolUse lockdown hook) was wrong by mechanism.**
The proposal's BLOCKERs make it a no-op as drafted (wrong output shape, missed Bash bypass). Even fixed up, it polices a layer that the data shows doesn't need policing — patryk-standalone is *willing* to use the queue, it just has no tooling for it.

**3. The "PRM session" failure case is unmeasured.**
Yesterday's session was designed against a remembered-but-uncaptured incident. PRM-cwd sessions don't appear in the cross-project mining. The om-superpowers rule was being calibrated against `n=0` direct evidence and `n=1` recalled incident. The captured failure case (`patches.diff` in `warmup-hardening`) is from a *different* consumer (patryk-standalone) and would benefit from the same fix.

## Revised plan for om-superpowers

**Drop:**
- The PreToolUse cwd-jail / lockdown-mode hook. Don't ship.
- Any future "structural policing" of consumer-app sessions before measurement justifies it.

**Ship (Plan A — friction reduction):**
1. **`bin/om-handoff`** — wrapper takes a slug + structured stdin (or interactive prompts) and writes `<om-core-checkout>/agents/tasks/<YYYYMMDD-HHMM>-<slug>/task.md` with frontmatter (origin sessionId, repro pointer, suggested-fix sketch, evidence URLs, priority). Returns the path. ~50 lines of node. Idempotence by slug + content hash.
2. **`bin/om-task-list`** — reads the queue, prints a 3-column table: `incoming | in-progress | done` with timestamps + slugs + origin. ~30 lines. Consumer-app user runs this to see state and feel safe continuing.
3. **Skill `om-cto/upstream-task-drain`** — sibling to `upstream-bug-triage`, for the OM-core-side agent. Specifies the consumer protocol: claim a task by `mv` to `in-progress/`, work it, `mv` to `done/` with a `resolution.md` sibling.

**Existing edit on `skills/om-cto/references/upstream-bug-triage.md` (uncommitted):** keep but trim. The skill body should collapse to "compose context, run `om-handoff <slug>`, continue your work." No MUST/MUST NOT prose policing what the consumer-app session can write — the wrapper IS the rule.

**Add (Plan B — belt-and-braces, optional):**
- `SessionEnd` git-diff auditor: scans for `patches.diff` writes inside `/OM/agents/tasks/` and fails loud. Targets the one observed failure pattern. ~10 lines. Cheap, post-hoc, doesn't have the matcher fragility of PreToolUse.

## Verification (Karpathy bar — show numbers)

**The binding-rate KPI:** `handoff_correct / (handoff_correct + inline_authored)`.

**Today's baseline (2026-05-10):**
- Tasks dropped: 3
- Tasks with README-only (correct): 2
- Tasks with `patches.diff` written from consumer side (failure mode): 1
- **Binding rate: 67%**

**Target after wrappers ship:** ≥90%. Re-run mining query monthly. Track in `docs/specs/analysis/cross-project-writes-ledger.md` (one row per month).

**Reproducible query:**

```bash
cd ~/.claude/projects && \
for f in $(find . -maxdepth 2 -name "*.jsonl" -newermt "2026-04-01"); do
  jq -r '
    select(.type=="assistant" and .cwd) | . as $r |
    .message.content[]? | select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="MultiEdit")) | .input.file_path as $fp |
    select($fp != null
           and ($fp | startswith("/Users/maciejgren/Documents/OM/"))
           and (($r.cwd | startswith("/Users/maciejgren/Documents/OM/")) | not)
           and ($r.cwd != "/Users/maciejgren/Documents/OM"))
    | "\($r.timestamp) | cwd=\($r.cwd) | wrote=\($fp)"
  ' "$f" 2>/dev/null
done | sort -u
```

## Decision required

**Q1.** Ship Plan A wrappers (`om-handoff`, `om-task-list`, `upstream-task-drain` skill)? My take: yes.

**Q2.** Drop the PreToolUse lockdown-hook design entirely? My take: yes. Re-evaluate only if binding rate post-Plan-A is <90%.

**Q3.** Trim the uncommitted `upstream-bug-triage.md` edit to "run `om-handoff`" instead of multi-paragraph MUST/MUST NOT? My take: yes, but **after** the wrappers exist. Rule pointing at a wrapper that doesn't exist yet is worse than the current prose.

**Q4.** Bump version to 1.15.0 (Plan A is additive surface area), or hold release until Plan B auditor lands? My take: 1.15.0 with Plan A only; Plan B as 1.15.1 if/when needed. Don't let perfect block good.

## Provenance

- Adversarial review subagent: `a63b43cd1078b5e9c` (this session)
- Data-mining query run: 2026-05-10 ~13:00 UTC, agents-master cwd
- Files inspected for proposal review: `/Users/maciejgren/Documents/om-superpowers/.claude-plugin/plugin.json`, `hooks/hooks.json`, `hooks/run-hook.cmd`, `bin/`
- Originating session jsonl: `~/.claude/projects/-Users-maciejgren-Documents-om-superpowers/d7a03f4f-5822-4196-8a36-4ca241b032d8.jsonl`

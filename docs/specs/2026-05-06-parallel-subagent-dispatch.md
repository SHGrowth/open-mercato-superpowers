# Parallel Subagent Dispatch Protocol

**Date:** 2026-05-06
**Status:** Draft — awaiting review
**Owner:** Mat (CEO)
**Related session evidence:** `patryk-standalone/standalone-app` session `c4f69f5f-65c3-4caa-b8c2-fbbab868fec4` (2026-05-05 17:39 UTC), three concurrent T0/T1/T2 audit agents under one `requestId`.

## TLDR

OM superpowers skills *describe* parallel subagent dispatch ("in parallel where independent") but never specify the operational rule that makes parallelism actually fire: **all independent `Agent` tool_use blocks must be emitted in a single assistant message**. Without this, the model satisfies the letter of the guidance by issuing serial dispatches across consecutive turns, blocking on each. This spec adds the protocol explicitly, gives orchestrator skills a worked fan-out template, and codifies a reusable "MVP gate audit" pattern that proved valuable in the 2026-05-05 PRM session.

## Problem

### Evidence

In the 2026-05-05 PRM "MVP gate cleared" session, the model dispatched three audit agents (one per implemented spec) inside a single assistant turn:

- All three `Agent` tool_use blocks shared `requestId: req_011Cajq6vkCix9YZSmyCVdpY`.
- Wall-clock proof of parallelism:
  - T0 agency-foundation: 17:39:25 → 17:43:26 (~4m 1s)
  - T1 wip-scoreboard:    17:39:42 → 17:42:57 (~3m 15s)
  - T2 attribution-loop:  17:40:08 → 17:42:25 (~2m 17s)
- Total wall time: ~4 minutes for work that would have taken ~9.5 minutes serially.
- Dispatch text: *"Module has 102 files. Dispatching three parallel agents — one per implemented spec — to do a section-by-section spec-vs-code audit."*

### Gap in current skills

| Location | Current language | Why insufficient |
|---|---|---|
| `om-implement-spec/SKILL.md:67` | *"Use subagents liberally to parallelize independent work"* | Says *what*, not *how*. Model can serialize across turns. |
| `om-implement-spec/SKILL.md:191` | *"Launch parallel subagents only for truly independent work."* | Same — no execution rule. |
| `om-cto/references/spec-orchestrator.md:16` | *"dispatch subagents in parallel where independent"* | Same. The per-feature numbered sequence below it (1→2→3→4) reads as a serial loop and biases the model toward serial dispatch. |
| `om-cto/references/pre-impl-analysis.md:221` | *"Launch parallel Explore agents for independent code areas (events, API routes, widgets, types)."* | Same. |

None of the four mention:
- Issuing multiple `Agent` tool_use blocks in one assistant message.
- A worked prompt template that makes fan-out tractable (identical shape across tracks).
- A reusable "audit at gate" pattern.

### Why it matters

- **Wall-clock cost.** A 3-track audit serialized takes ~3× longer.
- **Cache cost.** Each serial dispatch makes the parent re-read context between agent results. One-shot fan-out keeps the parent's cache warm through one tool-result batch.
- **Confidence.** Independent agents on the same prompt template produce comparable reports; serial dispatch tempts the model to let later agents "build on" earlier findings, which is exactly what we don't want at an audit gate.

## Design

### 1. New shared reference file

**Path:** `skills/_shared/parallel-dispatch.md`

A single source of truth that orchestrator skills link to. Contents:

- **Protocol rule.** *"When dispatching N independent subagents, emit all N `Agent` tool_use blocks inside one assistant message. The runtime executes them concurrently. Do not split them across consecutive messages — this serializes them and forfeits the parallelism."*
- **When to fan out.** Decision criteria: tracks must (a) not write to overlapping files, (b) not consume each other's output, (c) finish on a similar timescale (within ~3×).
- **Prompt-template rule.** Each parallel agent gets the *same prompt shape* with track-specific variables filled in (paths, scope, checklist). This makes results comparable.
- **Worked example: MVP-gate audit.** Reproduction of the 2026-05-05 patryk template, parameterized:
  - `{spec_path}` — full path to the spec being audited
  - `{cross_validation_path}` — path to cross-spec contracts doc, if any
  - `{module_root}` — path to module code root
  - `{section_checklist}` — §3–§9 verification list
- **What NOT to fan out.** Sequential dependencies (entity → API route → backend page); single-file edits; anything sharing a write target.

### 2. Edits to existing skills

#### `skills/om-implement-spec/SKILL.md`

Replace the soft "Use subagents liberally" paragraph (lines ~65–69) with:

> **Parallel dispatch protocol.** For independent work, fan out subagents — but emit all `Agent` tool_use blocks in a **single assistant message**. Splitting them across consecutive messages serializes them. See `skills/_shared/parallel-dispatch.md` for the protocol and worked template.

Replace the "Concurrency rule" line (~191) with:

> **Concurrency rule.** Parallel subagents only for truly independent work (no shared write targets, no input/output coupling). Emit all calls in one assistant message. Sequential dispatch (separate messages) for dependent files. See `skills/_shared/parallel-dispatch.md`.

#### `skills/om-cto/references/spec-orchestrator.md`

Replace the line *"dispatch subagents in parallel where independent"* (line 16) with a new sub-section before "Per-feature subagent sequence":

> **Across features, fan out.** When the decomposition has N independent features, dispatch one per-feature track per subagent — all in a single assistant message. Within a feature, the per-feature sequence below is serial (gap analysis must precede spec writing). See `skills/_shared/parallel-dispatch.md`.

Make explicit that the inner 1→2→3→4 is intra-feature serial, inter-feature parallel.

#### `skills/om-cto/references/pre-impl-analysis.md`

Replace line 221 with:

> **Parallel Explore fan-out.** Independent code areas (events, API routes, widgets, types, migrations) are dispatched as one Explore agent each, all in a single assistant message. See `skills/_shared/parallel-dispatch.md` for the protocol.

#### `skills/om-cto/SKILL.md`

Add a row to the Task Router (after line 24):

> | Multiple-track parallel dispatch (audit, decomposition, fan-out) | `_shared/parallel-dispatch.md` |

### 3. New "MVP-gate audit" pattern in `om-implement-spec`

Add a new subsection under Step 6 (Self-Review):

> **Step 6b — Multi-spec gate audit (when N≥2 specs of an MVP have landed).** Before declaring an MVP gate cleared, dispatch one audit subagent per implemented spec — in parallel, single message — using the template in `skills/_shared/parallel-dispatch.md` §Worked example. Each agent reports gaps/deviations, not a build summary. Block the gate on any High-severity finding.

This codifies the pattern Mat used on 2026-05-05.

## Out of scope

- `run_in_background` mode. Patryk session did not use it; foreground concurrent dispatch is enough for now. Revisit only if we hit dispatch-count limits.
- Worktree isolation for parallel writers. Out of scope because the protocol is read-only / advisory (audit, gap-analysis, cross-validation). Writers stay sequential.
- Dynamic agent-count throttling. Trust the runtime's concurrency policy; don't add our own cap.

## Success criteria

1. A future `om-cto` orchestrator run, given a 3-feature decomposition, produces three `Agent` tool_use blocks under a single `requestId` (verifiable in the JSONL transcript).
2. A future `om-implement-spec` run, at an MVP gate with N≥2 specs landed, dispatches one audit agent per spec in one assistant message.
3. The protocol reference is loaded **only when needed** (linked from the four touchpoints), preserving context budget.
4. Existing skills' word counts grow by ≤10 lines each; all bulk lives in the shared reference.

## Open questions

- **OQ-1.** Should `om-auto-create-pr` and `om-auto-continue-pr` also link the shared protocol? They currently don't fan out, but a multi-phase plan with independent phases could benefit. Defer to v2 unless Mat flags otherwise during review.
- **OQ-2.** Worked-example length: do we paste the full T0/T1/T2 audit prompt (~50 lines), or a stripped 15-line skeleton? Recommendation: **skeleton**, with a note pointing to the patryk session as the canonical worked example.
- **OQ-3.** Naming: `_shared/` directory has no precedent in this repo. Alternative: `skills/om-cto/references/parallel-dispatch.md` (since om-cto is the most common entry point) and let other skills cross-link to it. Recommendation: **co-locate under om-cto** to match existing conventions.

## Files touched (preview)

| File | Change | Lines |
|---|---|---|
| `skills/om-cto/references/parallel-dispatch.md` (new, per OQ-3) | Protocol + decision criteria + worked-example skeleton | ~80 new |
| `skills/om-implement-spec/SKILL.md` | Replace 2 paragraphs, add Step 6b | ~+15 / −6 |
| `skills/om-cto/references/spec-orchestrator.md` | Replace line 16 with sub-section | ~+8 / −1 |
| `skills/om-cto/references/pre-impl-analysis.md` | Replace line 221 | ~+3 / −1 |
| `skills/om-cto/SKILL.md` | Add Task Router row | +1 |

Total: ~80 new lines in one shared file, ~25 lines of edits across four skills.

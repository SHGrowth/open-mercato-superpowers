# Parallel Subagent Dispatch — Minimal Edit

**Date:** 2026-05-06
**Status:** Counter-proposal to `2026-05-06-parallel-subagent-dispatch.md`
**Owner:** Mat (CEO)
**Stance:** Land the smallest verifiable change. Collect data. Decide if more is needed.

## TLDR

The original spec adds ~80 lines of new shared reference + ~25 lines of edits + a new MVP-gate methodology. Evidence cited is one **success** case (Patryk 2026-05-05); no failure case where the model serialized when it should have parallelized. The model's system prompt already mandates one-message parallel tool_use, which is the most plausible cause of the observed parallelism — not the skills.

This counter-spec lands a 4-line edit (one per existing touchpoint) that makes the *mechanical* rule explicit, then waits for two om-cto sessions of evidence before doing anything else.

## What we are NOT doing yet (and why)

| Original proposal | Why deferred |
|---|---|
| `skills/_shared/parallel-dispatch.md` (~80 lines) | No failure case justifies an 80-line shared reference. OQ-3 in the original even admits `_shared/` has no precedent. |
| Worked-example skeleton (audit prompt) | The Patryk session is the worked example — link to it; don't paste it. |
| Step 6b "MVP-gate audit" methodology | Different concern. Methodology change should ride its own spec so it can be A/B'd separately from the dispatch fix. |
| Cache-cost claim | Asserted, not measured. Drop until benchmarked. |
| `om-cto/SKILL.md` Task Router row | Routes to a file we are not creating. |

## The change

Four single-line edits. Each adds the mechanical clause "— emit all `Agent` calls in one assistant message" to existing language.

### 1. `skills/om-implement-spec/SKILL.md:67`

**Before:**
> Use subagents liberally to parallelize independent work:

**After:**
> Use subagents liberally to parallelize independent work — emit all `Agent` tool calls in one assistant message (splitting them across messages serializes them):

### 2. `skills/om-implement-spec/SKILL.md:191`

**Before:**
> **Concurrency rule**: Launch parallel subagents only for truly independent work. Sequential for dependent files.

**After:**
> **Concurrency rule**: Launch parallel subagents only for truly independent work, all in one assistant message. Sequential (separate messages) for dependent files.

### 3. `skills/om-cto/references/spec-orchestrator.md:16`

**Before:**
> For each feature in the decomposition, dispatch subagents in parallel where independent:

**After:**
> Across independent features, dispatch one subagent per feature in a single assistant message (this is what makes them run concurrently). The per-feature sequence below is intra-feature serial.

This also fixes the latent bias: the numbered 1→2→3→4 below line 16 reads as serial and was probably the strongest serial-dispatch nudge in the codebase.

### 4. `skills/om-cto/references/pre-impl-analysis.md:221`

**Before:**
> Launch parallel Explore agents for independent code areas (events, API routes, widgets, types).

**After:**
> Launch parallel Explore agents for independent code areas (events, API routes, widgets, types) — all in one assistant message.

Total: +4 lines net, 0 new files, 0 new methodology.

## Verification (data, not vibes)

This change is verifiable on real sessions, not on prompt-output shape alone. Concretely:

1. **Capture baseline.** Find ≥3 past om-cto / om-implement-spec sessions in `~/.claude/projects/` where independent tracks were dispatched. For each, count: did they share a `requestId` (parallel) or land on consecutive turns (serial)?
2. **Land the 4 edits.**
3. **Run two new sessions** with multi-feature decomposition or multi-spec audit. Capture the same requestId metric.
4. **Decision rule:**
   - If baseline already shows ≥80% parallel dispatch (system-prompt is doing the work), the 4 edits are belt-and-suspenders — land them anyway, do nothing further.
   - If baseline shows serial dispatch and post-edit shows parallel, the 4 edits worked — done.
   - If post-edit still shows serial dispatch, **then** invest in the worked template / shared reference. We will have an actual failure transcript to design from.

## What stays from the original spec

- Diagnosis that current language is descriptive ("in parallel where independent"), not mechanical ("in one message"). Correct, fixed by the 4 edits.
- The intra-feature serial / inter-feature parallel distinction in `spec-orchestrator.md`. Real ambiguity, fixed by edit #3.
- "What NOT to fan out" criteria are useful — but as inline guidance, not a separate file. If/when we need them, inline them in the touchpoints.

## Open questions

- **OQ-1.** Does the baseline (Step 1 of Verification) actually show a serial-dispatch problem? If not, even the 4-line edit is optional — though cheap enough to land regardless.
- **OQ-2.** If we find serial dispatch, what's the minimum prompt change in `spec-orchestrator.md` line 16 that flips it? Test that hypothesis, not a doctrine.

## Files touched

| File | Change | Lines |
|---|---|---|
| `skills/om-implement-spec/SKILL.md` | 2 inline edits | +2 / −2 |
| `skills/om-cto/references/spec-orchestrator.md` | 1 inline edit | +1 / −1 |
| `skills/om-cto/references/pre-impl-analysis.md` | 1 inline edit | +1 / −1 |

Total: 4 lines changed. No new files. No methodology changes.

## Relation to the original spec

If the verification step uncovers an actual failure mode, the original spec's worked-example template and shared reference become the natural follow-up. This counter-spec is **not** an alternative to that future work — it is the prerequisite that decides whether that work is needed.

# ANALYSIS — upstream handoff (v2 — supersedes the Plan A recommendation in v1)

**Date:** 2026-05-10 (later in the day, after parallel-session review)
**Author:** Claude (agents-master meta-session)
**Supersedes:** the "Ship Plan A wrappers" recommendation in `ANALYSIS-2026-05-10-upstream-handoff-baseline.md`. The empirical baseline section of v1 stands; the **plan** changes.

## TL;DR

v1 of this analysis recommended shipping `bin/om-handoff` + `bin/om-task-list` as friction-reduction wrappers. That recommendation was wrong by Musk Step 1 ("question the requirement"). The wrapper does five jobs the model can do directly with `Read` / `Write` / one `Bash mkdir`, and adding the wrapper actually **inverted the friction goal**: a "skeleton then fill" pattern is two round trips, while a single `Write` with the substance composed in one shot is one round trip.

Plus the parallel session's 1.15.0 draft hit two BLOCKERs that only exist because the wrapper exists (heredoc interpolation leaking producer-local path into the README the drain agent reads; wrapper not on `$PATH` from consumer-app session). Deleting the wrapper eliminates both.

The simpler 1.15.0 ships **the convention in the skill body**, no bin/ additions.

## Why the wrappers should not ship

Five jobs `bin/om-handoff` does, vs. native tools the model already has:

| Wrapper job | Native equivalent | Net |
|---|---|---|
| Resolve OM-core path (env → config → prompt → persist) | `Read ~/.config/om-superpowers/handoff.json`; if missing, ask user, `Write` the config | Same primitives, no wrapper needed |
| Validate slug regex | Skill body states the regex; drain catches violations anyway | Wrapper validation not load-bearing |
| `mkdir` task folder | One `Bash mkdir -p` or implicit via `Write` | Wrapper adds no value here |
| Write 9-section README **skeleton** | `Write` the README with substance composed inline | Wrapper inverts friction: skeleton→Edit×9 is 2+ round trips; direct Write is 1 |
| Return path | Path is the operation's input | Trivial |

`bin/om-task-list`: read-only renderer of queue state. Agent can `find <om-core>/agents/tasks/ -maxdepth 2 -type d`. The CLI is a minor ergonomic for a human operator typing in a terminal — not the agent's binding path. Drop with `om-handoff` for consistency; if a human ergonomic CLI is wanted later, ship as 1.16 against measured demand.

**Cost of keeping the wrappers in 1.15.0 as currently drafted:**
- BLOCKER 1 (`bin/om-handoff:146`): unquoted heredoc interpolates `$OM_CORE` (producer-local path) into the README the drain agent reads.
- BLOCKER 2: wrapper not on `$PATH` in consumer-app session; binding mechanism unreachable.
- ~270 lines of bash 3.2-compatible code (handoff + task-list combined) to maintain.
- Test surface that doesn't exist yet.
- CLI commitment around `om-handoff` arguments (renaming or restructuring becomes a breaking change).

Both BLOCKERs disappear when the wrapper disappears. The bash test surface disappears. The skeleton-vs-Write inversion disappears.

## What 1.15.0 should ship instead

**The producer convention lives in `skills/om-cto/references/upstream-bug-triage.md`.** The "Upstream patch handoff" section (currently 12 lines pointing at `bin/om-handoff`) is rewritten to specify, inline, what the model does:

1. **Resolve the OM core path.** Read `~/.config/om-superpowers/handoff.json`'s `om_core_path` key. If the file doesn't exist, ask the user once for the absolute path, then `Write` the config so future sessions don't re-ask. (Spec the JSON shape: `{"om_core_path": "<absolute path>"}`.)
2. **Drop the task.** Use `Write` (not Edit) to create `<om-core-checkout>/agents/tasks/<YYYY-MM-DD>-<slug>/README.md` with the README template inline in the skill body, substance composed at write time. `<om-core-checkout>` stays verbatim as the placeholder in any code-block examples within the README so the drain agent reading on a different machine doesn't see a stale absolute path. Slug regex stated in the skill body: `^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$`, no double hyphens.
3. **Stop the upstream-patch portion of the task. Report the folder path back to the user.**

The README template (already designed and tested in the wrapper's heredoc) moves into the skill body verbatim, with two adjustments: (a) `<om-core-checkout>` placeholder kept literal everywhere, and (b) the "Suggested PR metadata" section either added to the template or the reference to it removed from `upstream-task-drain.md:46`. Pick one; ship consistent docs.

`upstream-task-drain.md` (consumer-side protocol) ships unchanged. `git mv` claim lock, `Read` the README, branch off `origin/main`, patch + tests + PR, `git mv` to `done/` + `resolution.md`. Already correctly designed.

## Updated Q1–Q4

Re-answering the v1 decision matrix:

**Q1.** Ship the wrappers (`om-handoff`, `om-task-list`)? **No.** Delete both from the working tree. Ship the convention in the skill body.

**Q2.** Drop the PreToolUse lockdown-hook design? **Still yes.** The cwd-jail / hook approach is independent of the wrappers and remains rejected.

**Q3.** Trim `upstream-bug-triage.md` to point at the convention (was: "point at the wrapper")? **Yes**, but the trim is now a *rewrite* of the "Upstream patch handoff" section to spec the convention inline, not a one-line wrapper reference. Net: ~30 lines added to the skill body, ~12 lines removed. The skill grows slightly; the bin/ shrinks to zero.

**Q4.** Bump version to 1.15.0? **Yes.** The release is now a doc + skill change, not a code addition. New `upstream-task-drain.md` skill + formalized producer convention in `upstream-bug-triage.md` is real surface area worth a minor bump.

## Net diff vs. the parallel session's current working tree

**Delete:**
- `bin/om-handoff` (untracked, never committed)
- `bin/om-task-list` (untracked, never committed)

**Rewrite:**
- `skills/om-cto/references/upstream-bug-triage.md` — replace the current "Upstream patch handoff" section that points at `bin/om-handoff` with the inline-convention version (path resolution + Write template + stop-and-report). Action table rows for `confirmed-new-bug` updated to say "compose and `Write` the task per the convention in the section above" instead of "run `bin/om-handoff <slug>`".
- `CHANGELOG.md` — replace the 1.15.0 entry. New shape: *"upstream-bug-triage now specifies the producer-side handoff convention inline; new `upstream-task-drain.md` reference for the consumer-side protocol. A producer-wrapper (`bin/om-handoff`) was drafted and deleted in favor of native-tool composition per Musk Step 2 — see `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md` for the reasoning."* Smaller, more honest entry.
- `README.md` — the v1.15.0 callout needs to drop the `bin/om-handoff` references and instead describe the convention.

**Keep:**
- `skills/om-cto/references/upstream-task-drain.md` (untracked, ships as-is — consumer-side protocol is unchanged).
- `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline.md` (v1, untracked) — keep for provenance; the "Empirical baseline" section is still the data of record. Add a top-line note pointing at v2.
- `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md` (this file) — the new actionable doc.
- `.claude-plugin/plugin.json` + `marketplace.json` version bumps to 1.15.0 — still appropriate.

## Verification (unchanged from v1)

Binding-rate KPI: `handoff_correct / (handoff_correct + inline_authored)`. Today's baseline 67%. Target after release: ≥90%. Re-run the mining query monthly. Plan B (`SessionEnd` git-diff auditor scanning for `patches.diff` writes inside `/OM/agents/tasks/` from non-OM `cwd`) still held for 1.15.1 if Plan A measurement says the convention alone isn't enough.

The mining query in v1's "Verification" section is reproducible and the metric is unchanged. Only the **mechanism** that drives the metric changed (skill body, not wrapper).

## Why the simpler shape may bind better than the wrapper would have

The wrapper's binding logic was: *the model reads the skill body, decides to follow it, runs the wrapper.* The convention's binding logic is: *the model reads the skill body, decides to follow it, runs `Write`.* Both are prose-channel binding (per the agents-master `feedback_text_channel_does_not_bind` finding, N=17). Neither is a hard structural enforcement.

But the convention has **lower friction** at every step — no PATH resolution, no skeleton round trip, no wrapper-not-found failure mode. **And the failure mode is more legible:** if the model skips the convention, `git diff` shows missing `agents/tasks/` writes. If the model skipped the wrapper, you'd see the same gap, plus possibly a confused half-attempt at running `om-handoff` followed by an inline patch.

The Karpathy line: *"simple verifiable rule"*. The convention is the simpler rule. Ship the simpler rule and measure.

## Provenance

- v1 of this analysis: `ANALYSIS-2026-05-10-upstream-handoff-baseline.md`
- Parallel session that drafted Plan A: `~/.claude/projects/-Users-maciejgren-Documents-om-superpowers/d7a03f4f-5822-4196-8a36-4ca241b032d8.jsonl`
- Adversarial review subagent of the prior PreToolUse-hook proposal: `a63b43cd1078b5e9c`
- Triggering question (Musk Step 1, asked by Maciej in agents-master meta-session): *"why bin/om-handoff?"* — and the answer is: it shouldn't exist.

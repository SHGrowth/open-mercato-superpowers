# Changelog

## 1.15.0

### Added — upstream patch handoff (producer convention + consumer drain protocol)

Closes the producer-consumer loop on upstream OM core fixes — as a documented convention the model executes with native tools (`Read` / `Write` / one `Bash` find), not a CLI wrapper. A consumer-app session (PRM, patryk-standalone, any other downstream app) reads the OM core checkout path from `~/.config/om-superpowers/handoff.json` (asking the user once and persisting if missing), then `Write`s a self-contained task folder at `<om-core-checkout>/agents/tasks/YYYY-MM-DD-<slug>/README.md` with the README template inline in the skill body. A separate session running with `cwd` inside the OM checkout drains that queue per the new `skills/om-cto/references/upstream-task-drain.md` — landing the patch upstream without ever cross-contaminating the two repos.

**Driven by** `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline.md` (empirical baseline) + `ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md` (Musk-Step-1 review of the wrapper plan). The baseline mined 16 cross-project handoff writes since 2026-04-01 across three real tasks dropped on 2026-05-10. Without any rule, the binding rate was **67%** (2 of 3 README-only handoffs as intended; 1 task had a `patches.diff` written from the consumer side — the failure mode this release closes).

#### Why a convention, not wrappers

A `bin/om-handoff` + `bin/om-task-list` wrapper pair was drafted earlier in the day and **deleted before commit** after Musk-Step-1 review. Five jobs the wrapper would do — resolve the OM-core path, validate slug regex, `mkdir` the folder, write a 9-section skeleton, return the path — all reduce to native primitives the model already has. The skeleton-then-Edit pattern actually inverted the friction goal: two round trips where a single `Write` with substance composed inline is one. Two BLOCKERs that only existed because the wrapper existed (heredoc interpolation leaking the producer-local path into the README the drain agent reads on a different machine; wrapper not on `$PATH` from a consumer-app session) disappeared with the wrapper. The convention's binding logic is identical to the wrapper's — both are prose-channel binding (per the agents-master `feedback_text_channel_does_not_bind` finding, N=17) — but the convention has lower friction at every step and a more legible failure mode: a missed handoff shows up as the absence of writes under `agents/tasks/`, not a confused half-attempt to invoke a wrapper that wasn't on PATH.

The PreToolUse cwd-jail / lockdown-mode hook (the alternative structural-policing approach) was rejected separately. Adversarial review found 2 BLOCKER issues (matcher missed `Bash` writes via `cat > file` and `sed -i`; proposed `{"decision":"block"}` is `Stop` semantics, not `PreToolUse`) and 4 SERIOUS issues. Friction reduction beats structural policing when the population is willing — and the data shows consumer-app sessions are willing.

#### What ships

- **`skills/om-cto/references/upstream-bug-triage.md`** — the "Upstream patch handoff" section is rewritten to spec the convention inline, three steps the model performs with native tools: (1) `Read` `~/.config/om-superpowers/handoff.json`'s `om_core_path` key, ask the user once and `Write` the config if missing; (2) compose substance and `Write` `<om-core-checkout>/agents/tasks/<YYYY-MM-DD>-<slug>/README.md` with the template (inline in the skill body, `<om-core-checkout>` placeholder kept literal in example commands so the drain agent on a different machine doesn't see a stale absolute path); (3) stop the upstream-patch portion of the task, report the folder path back to the user. Slug regex (`^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$`, no double hyphens) stated in the skill body. Action-table rows for both `confirmed-new-bug` recommendations updated. New `upstream_patch_task_path` YAML field in the structured verdict output. Boundary section gains a fourth bullet: "does not author the upstream core patch from the consumer-app session." Why-this-exists gains a fourth failure mode: "Cross-repo patch contamination." Net: ~70 lines added to the skill body, prior wrapper-pointing prose removed.
- **`skills/om-cto/references/upstream-task-drain.md` (new)** — consumer-side protocol for the OM-side agent. Sibling reference under `om-cto`, NOT a new top-level skill (per skill-surface-budget rule: bug-triage and task-drain are two phases of the same architectural concern). Specifies claim protocol (`git mv` to `in-progress/` is the lock — race losers fail loudly), work protocol (re-verify anchors against current upstream sha → branch off `origin/main` → patch → tests → PR to your fork), done protocol (`git mv` to `done/` + sibling `resolution.md` linking the merged PR back to the originating downstream task with a removal trigger for any consumer-side workaround), and rejection/pushback path.

#### Verification target (Karpathy bar)

Binding-rate KPI: `handoff_correct / (handoff_correct + inline_authored)`. Today's baseline 67%. Target after release: ≥90%. Re-run the mining query monthly. Plan B (`SessionEnd` git-diff auditor scanning for `patches.diff` writes inside `/OM/agents/tasks/` from non-OM `cwd`) held for 1.15.1 if Plan A measurement says the convention alone isn't enough.

Reproducible mining query lives in the v1 analysis doc.

### Files touched

- `skills/om-cto/references/upstream-bug-triage.md` — rewrote "Upstream patch handoff" section to spec the convention inline (Read config / Write template / stop). Added `upstream_patch_task_path` YAML field, updated action table for both `confirmed-new-bug` rows, updated boundary + reporting-back, added fourth failure mode in why-this-exists.
- `skills/om-cto/references/upstream-task-drain.md` (new) — consumer-side drain protocol reference.
- `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline.md` (new) — empirical baseline + mining query + rejected `PreToolUse` lockdown proposal. Top-line note added pointing at v2 for the plan section.
- `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md` (new) — Musk-Step-1 review of the wrapper plan; specifies the convention shape that actually shipped.
- `CHANGELOG.md` — this entry.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.15.0.
- `README.md` — v1.15.0 callout.

#### Cross-refs

- v1.12.1 (`upstream-bug-triage` discipline — the producer-side triage rule this release operationalizes for the patch-authoring path)
- agents-master `feedback_text_channel_does_not_bind` (the prose-channel binding limitation that applies equally to convention and wrapper, and informed the choice not to over-engineer)

## 1.14.0

### Added — `bin/claude-validated` output validator wrapper

Implements `agents-master/improvements/I018.md` — a structural validator that wraps `claude -p` (headless mode) and runs 5 deterministic regex checks against stdout. On any FAIL: rejects + retries with reinforcement (up to 2 retries). After retry budget: exits 1 with named FAIL on stderr. Silent fabrication is no longer an option for the "does platform X cover capability Y" prompt class in headless mode.

**Driven by** S008 → S010 → S011 — 16 data points across 4 progressively-tightened text-channel gates (HARD-GATE prose, `## Sources` mandate from I014, Phase 6 doubt-check from I016, ROUTING CHECK addition from I017) all empirically establishing that prose rules in skill bodies do not bind `claude -p --model claude-opus-4-7` for fabrication-shape failures. Plus one deletion experiment (Replace Advisory with Research Plan) that also failed: agent read the new template four times then violated every Hard Rule. Skill text channel is dead for this prompt class. The wrapper bypasses it entirely — skill text becomes advisory; the regex is normative.

#### What it catches

- **#1 Percentage without N/M fraction** — `~70%` without backing fraction (`8/11 covered`) → FAIL
- **#2 English hedges** — `approximately`, `around`, `roughly`, `~[0-9]` → FAIL
- **#3 Persona invocation** — `Piotr`, `Cagan`, `Piotr-style`, `Cagan-style` used as authority labels → FAIL (cite rule numbers from `references/piotr-decision-library.md`, never the persona name as label)
- **#4 Polish hedges** — `szacunkowo`, `około`, `mniej więcej`, `w przybliżeniu` (locale-restrictive: output must be English) → FAIL
- **#5 Effort estimates without enumeration** — `6-8 modules` without per-module list → FAIL

#### Locale-restrictive design

The wrapper prepends a `LOCALE_RULE` requiring English output regardless of input language, so an English-only regex set suffices. Addresses S011's finding that fabrication shape transfers across languages — agent matching user's Polish prompt was the carrier wave for the fabrication. Removing the language-mirroring instinct removes one transfer surface. Cost: Polish-speaking users reading English answers about platform capabilities; acceptable given the user is the developer here, not the end customer; final user-facing answers can be re-localized as a separate step after grounding holds.

#### Empirical retry trajectory (verified 2026-05-09)

ISO 9001 prompt against patched wrapper (transcripts captured):

- Retry 0: 3 FAILs (`#2` hedge, `#3` persona, `#5` effort estimate)
- Retry 1: 1 FAIL (`#3` persona) — narrowed
- Retry 2: 1 FAIL (`#5` effort regex precision); output structurally near-compliant — 10 modules enumerated explicitly with descriptions, fractions `7/7`, `10/10`, `4/4` instead of percentages, zero persona invocations
- Exit 1 with named FAIL surfaced on stderr

Retry-into-compliance empirically works; failure to PASS within retry budget on this specific prompt is due to validator `#5`'s effort-estimate regex precision (fires on `10 modules` mention even when 10 modules are explicitly enumerated). Tuning deferred until N≥3 false-fire cases accrue from real use — picked from data, not pre-commit.

#### Downstream stdin-fix vs spec verbatim

I018's spec used `cat` inside the retry loop, but stdin is consumed by retry 0 — retries 1+ then received only `LOCALE_RULE` without the original prompt and the model emitted orientation messages instead of retried-answer-with-reinforcement (verified empirically before the fix: vacuous PASS on retry 2). Three-line downstream fix: `PROMPT=$(cat)` once at top, `printf '%s\n' "$PROMPT"` in retry pipeline. Aligned with spec intent (retry-with-reinforcement); does not modify spec semantics. Synced as implementation note to agents-master.

#### Usage (opt-in)

The wrapper is opt-in tooling — not auto-injected anywhere. Symlink to PATH or invoke via full path:

```bash
echo "<question>" | ~/Documents/om-superpowers/bin/claude-validated --model claude-opus-4-7

# Or symlink for short invocation
ln -sf ~/Documents/om-superpowers/bin/claude-validated ~/bin/claude-validated
```

#### What it does NOT cover (named for honesty)

- Interactive Claude Code sessions (this chat) — wrapper is post-emit, not streaming; no insertion point in a live session
- Claude Desktop, Claude Web — wrapper is a bash script, terminal-only
- Plain `claude` invocations without `-p` — wrapper specifically targets headless mode
- Other prompt classes (spec writing, implementation orchestration) — each needs its own validator regex set if the same fabrication shape appears
- The model's training-internalized output shape — the wrapper addresses the symptom (fabrication leaks past skill body), not the cause

For interactive enforcement, Claude Code hooks would be needed (option (b) from S011, deferred until empirical demand).

### Refactor — om-cto/SKILL.md persona-prune

Empirical evidence from probe 3 of the S011 verification chain: `# Piotr — advisory:` H1 fired as a fabrication shield even after `piotr-decision-library.md` prune. SKILL.md was the load-bearing surface for the persona shield, not the library file.

This release removes:
- `# Piotr` H1 (replaced with `# om-cto`)
- Persona-narrative paragraph ("Piotr Karwatka — CTO of Open Mercato, 1,400+ contributions...")
- "Red Flags" `Piotr says` table (8 rows)

Four surviving "Piotr" references in lower SKILL.md sections (Task Router row, User Proxy Integration, Architecture Direction, closing line) were not load-bearing per probe 3 data and are intentionally left for a future surgical pass if needed. The wrapper's validator `#3` catches residual prose-level invocations regardless of where in the skill the persona content lives — the persona does not need to be pruned everywhere, just out of the output.

### Files touched

- `bin/claude-validated` (new) — bash wrapper, ~80 lines, executable. Implements I018 with downstream stdin-fix. Already landed standalone in commit `8ca946c`.
- `skills/om-cto/SKILL.md` — persona-prune, 2 hunks (-13 net lines). Already landed standalone in commit `c288c45`.
- `CHANGELOG.md` — this entry.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.14.0.
- `README.md` — v1.14.0 callout in Quality & Testing section.

The two functional commits (`c288c45` + `8ca946c`) landed during the verification work and were pushed standalone before this version bump. This release commit packages them with the manifest bump so users actually receive both changes via `/plugins marketplace update`.

#### Cross-refs

- `agents-master/improvements/I018.md` (wrapper spec, output-validator design)
- `agents-master/sessions/S011.md` (failure analysis driving I018: 4 replays of progressively-tightened text gates, all bypassed)
- `agents-master/improvements/I017.md` (Musk Step 2 attempt: replace Advisory with Research Plan; empirically failed; partial revert kept SKILL.md persona-prune)
- `agents-master/improvements/I016.md` (Phase 6 doubt-check; in-vitro adoption test passed but in-vivo deployment via skill-text channel failed; superseded by I018)

## 1.13.0

### Added — DS Guardian sync infrastructure (`scripts/sync/ds.mjs`)

`om-ds-guardian` references are now kept in sync with upstream OM canonical DS docs via a manual sync script. Run `node scripts/sync/ds.mjs` from the plugin root to:

- **Mirror** `.ai/ds-rules.md` and `.ai/ui-components.md` from upstream `open-mercato/open-mercato@develop` into `om-reference/.ai/`. Two upstream files, both authoritative for tokens and primitive contracts; on conflict with hand-curated content, upstream wins.
- **Source-extract** 11 specialized inputs (ComboboxInput, DatePicker, DateTimePicker, EventPatternInput, EventSelect, LookupSelect, PhoneNumberField, SwitchableMarkdownInput, TagsInput, TimeInput, TimePicker) from `packages/ui/src/backend/inputs/*.tsx` into `skills/om-ds-guardian/references/specialized-inputs.md`. The bridge exists because upstream `.ai/ui-components.md` does not yet document specialized inputs (per `.ai/design-system-audit-2026-04-10.md`'s "defer to their own sections when they land" note); upstream issue [open-mercato/open-mercato#1874](https://github.com/open-mercato/open-mercato/issues/1874) tracks the canonical doc gap.
- **Discover** new/removed/changed upstream files in tracked directories (`.ai/`, `packages/ui/src/backend/inputs/`, `packages/ui/src/backend/`) by diffing against `skills/om-ds-guardian/.last-sync.json`. Deltas surface as action items in `sync-reports/YYYY-MM-DD-HHMM.md`.
- **Smoke-test** mirrored content (e.g., "ds-rules.md has Colors section", "specialized-inputs.md has TagsInput section") so a malformed mirror does not silently break downstream skill rules.

The script pins to a single upstream commit SHA per run (resolved at start), is idempotent (re-runs with the same SHA are no-ops), supports `--dry-run` for preview without writing, fails loudly (non-zero exit) on gh API errors / missing manifest entries / smoke test failures, and writes atomically (write-then-rename per file).

**Driven by** the user's review of PRM `caseStudyForm.tsx`, where DS Guardian REVIEW gave 10/10 to `<Input value="comma,separated,slugs">` for multi-value dictionary fields. Investigation surfaced that the upstream `<TagsInput>` primitive ships in `@open-mercato/ui@0.5.0`, is documented in source, and is used in 10+ core call-sites — but our hand-curated `references/component-guide.md` had no mention of it. The drift was structural: skill references were written at one point in time and never resynced as upstream evolved. This release closes the gap and prevents the same failure mode for future primitives.

#### Tier model

DS Guardian now layers references in three tiers:

| Tier | Source | Authority | Examples |
|------|--------|-----------|----------|
| **1 — Upstream-mirrored** | `open-mercato/open-mercato` canonical docs | Wins on conflict | `om-reference/.ai/ds-rules.md`, `om-reference/.ai/ui-components.md` |
| **2 — Source-extracted bridge** | `packages/ui/src/backend/inputs/*.tsx` (TS source) | Best-effort until upstream docs catch up | `references/specialized-inputs.md` |
| **3 — Skill-curated** | Hand-maintained in this repo | DS Guardian recipes layered on top | `references/component-guide.md`, `references/token-mapping.md`, `references/page-templates.md` |

#### New `mirrors-docs` relationship in `UPSTREAM.md`

Sibling to existing `extends` (upstream skill plugin), `composes` (orchestration), and `independent` (no upstream) — `mirrors-docs` is for skills that downstream-enforce upstream canonical *documentation* (not skill plugins). Pattern generalizes: future shadowing skills (om-data-model-design, om-system-extension, om-module-scaffold, om-backend-ui-design) can adopt the same shape (manifest + discovery + extract + smoke test + report) when their upstream canonical docs land. Pilot validated the shape; rolling out to other skills is staged.

#### Cadence

Manual trigger only — no cron. The user runs `node scripts/sync/ds.mjs` from the plugin root when they want fresh upstream content. Idempotent re-runs are cheap (no-op exit), so re-running before each release is the recommended cadence. When upstream evolves, the discovery scan flags new/removed/changed files in the report, and the human decides routing (add to manifest, ignore, escalate to a new skill, or file an upstream issue).

#### Files touched

- `scripts/sync/ds.mjs` (new) — single-file sync script; manifest + discovery + extract + smoke test + dry-run + atomic writes + idempotency. Uses `gh api` (already authenticated for plugin users) for upstream calls; no node deps.
- `skills/om-ds-guardian/sync-config.json` (new) — manifest: 2 mirror paths, 1 extract group (11 inputs), 3 discovery paths, 4 smoke tests, upstream `open-mercato/open-mercato@develop`, tracking issue `#1874`.
- `skills/om-ds-guardian/.last-sync.json` (new) — snapshot from last successful sync; fuels discovery diff for the next run.
- `skills/om-ds-guardian/sync-reports/2026-05-08-1930.md` (new) — first official sync report (Tier 1: 2 mirrors written, Tier 2: 11 primitives extracted, 0 discovery deltas, 4 smoke tests passed; pinned to upstream `b39fb4d`).
- `skills/om-ds-guardian/references/specialized-inputs.md` (new, auto-generated) — Tier 2 bridge for the 11 specialized inputs with provenance header, decision rule table, anti-pattern callout for CSV-in-Input, and per-primitive sections (source link, import path, exported types, defaults from destructuring).
- `om-reference/.ai/ds-rules.md` (new, mirrored) — canonical DS foundation rules (~19KB, mirrored verbatim from upstream).
- `om-reference/.ai/ui-components.md` (new, mirrored) — canonical primitive contracts (~36KB, mirrored verbatim from upstream).
- `skills/om-ds-guardian/SKILL.md` — added Tier 1/2/3 reference layers section + Sync section + run-this-manually command.
- `UPSTREAM.md` — added `mirrors-docs` relationship to taxonomy; updated `om-ds-guardian` row from `independent` to `mirrors-docs` with upstream paths and pinned commit `b39fb4d`.
- `README.md` — v1.13.0 callout under Quality & Testing skills section linking to upstream issue #1874.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.13.0.

#### Upstream issue filed

[open-mercato/open-mercato#1874](https://github.com/open-mercato/open-mercato/issues/1874) — "`.ai/ui-components.md` missing Specialized Inputs section". Asks upstream to add a "Specialized Inputs" section covering the 11 primitives with decision rule + props summary + anti-pattern callouts. When that lands, our Tier 2 extract becomes redundant — sync's discovery scan will flag the new upstream section and we can collapse Tier 2 into Tier 1 mirror.

## 1.12.1

### Added — upstream-bug-triage discipline

Suspected OM core (`@open-mercato/*`) bugs no longer get silent workarounds. Any om-superpowers agent that finds itself thinking "OM is broken, let me work around it" MUST route through `om-cto/references/upstream-bug-triage.md` before patching. om-cto verifies the bug, drafts the upstream issue + downstream tracking task, returns a verdict (`not-a-bug` / `already-reported` / `confirmed-new-bug`) and a workaround-size classification (`minor` / `major`); the calling agent does the actual `gh issue create` filings and applies the patch (or stops and reports to user).

**Driven by** the user's observation that downstream agents accumulate undocumented workarounds whenever core misbehaves — three failure modes: real bugs never reach the OM core team, workarounds without removal triggers outlast their cause by years, and "minor for now" workarounds become permanent because no one remembers they were temporary.

#### Workaround size rule

| Class | Definition | Recommendation |
|-------|------------|----------------|
| **Minor** | ≤50 LOC, single downstream file, no abstraction leakage, no public API surface touched, no repetition of upstream logic. | Apply workaround AND file upstream issue + downstream removal-trigger task. |
| **Major** | >50 LOC, OR multi-file, OR leaks abstractions, OR forks/copies upstream logic, OR would repeat at every call site. | Wait for upstream fix. File upstream + downstream blocker. Stop the run. Report to user. |

A 30-LOC change that wraps a core helper across 5 call sites = **major** (leaks into the call graph). A 60-LOC change that's a single guard at one call site with a clear `// remove when @open-mercato/<pkg>#<N> ships` marker = **minor** (containable, removable). When in doubt, recommend major — workaround tech debt outlasts the original deadline.

#### Paper trail required

Every workaround MUST have:
1. An upstream issue at `open-mercato/open-mercato`.
2. A downstream tracking task with a removal-trigger marker.
3. A code comment of the form `// remove when @open-mercato/<pkg>#<N> ships`.

`om-code-review` flags any workaround missing any of those three as **Critical**, regardless of size.

#### Files touched

- `skills/om-cto/references/upstream-bug-triage.md` (new) — verification protocol, verdict matrix, size rule, issue/task templates, om-cto-does-not-file boundary.
- `skills/om-cto/SKILL.md` — Task Router row + new triggers ("upstream bug", "OM core seems broken", "workaround for OM").
- `skills/om-troubleshooter/SKILL.md` — Rules section, route-through-om-cto rule.
- `skills/om-auto-create-pr/SKILL.md` — Rules section, route-through-om-cto rule scoped to step 6 (implementation).
- `skills/om-auto-continue-pr/SKILL.md` — Rules section, route-through-om-cto rule scoped to the resume path (resume agents are at especially high risk of mistaking "core misbehaves" for "push past this").
- `skills/om-system-extension/SKILL.md` — Rules section, route-through-om-cto rule (eject is allowed only after `confirmed-new-bug` + `wait-for-upstream` unacceptable + user approval).
- `skills/om-code-review/SKILL.md` — new "Silent Upstream Workarounds (Critical)" sub-section in Quick Rule Reference.
- `skills/om-orchestrate/prompts/coding-agent.md` — Rules section, autonomous-fleet variant of the rule (route through om-cto, on `wait-for-upstream` set `status:blocked`+post upstream link+exit).
- `README.md` — v1.12.1 callout above the v1.12.0 callout describing the new triage discipline.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.12.1.
- `CHANGELOG.md` — this entry.

#### What this is NOT

- NOT a new top-level skill (per the v1.12.0 surface-budget rule). The triage logic lives as an on-demand reference inside `om-cto`.
- NOT a replacement for ejection — ejection is still the last resort when UMES is genuinely insufficient. Triage clarifies whether the trigger for ejection is real or imagined.
- NOT a gate that blocks legitimate fast paths — `not-a-bug` verdicts return correct usage in the same hop, no filings needed.

## 1.12.0

### Added — `om-orchestrate` skill (Phase 1 of the road to v1.14.0 oneshot)

A new top-level skill that runs a fully autonomous agent fleet via GitHub Issues + labels + PR comments. Phase 1 ships single-agent + e2e-singleton + auto-merge mode. Phase 2 (v1.13.0) raises `parallel_n` for multi-agent; Phase 3 (v1.14.0) closes the loop with full failure recovery + Projects v2 view. End state of v1.14.0: typing `/om-orchestrate <app-spec>` produces merged PRs with no human babysitting.

**Driven by** the user's stated goal — *oneshot OM systems* — and three failures observed in PRM forensics: v1.11.5 (agents sleeping during /loop self-pace) was the *symptom*; the *cause* was no peer to yield to. v1.11.6 (review-skipped) was the *symptom*; the *cause* was no downstream gate that another agent enforced. v1.12.0 builds the substrate: an agent that yields work via labels and another agent that picks it up.

#### Skill structure (context-budget discipline)

The entire orchestration system adds **at most one new top-level skill** to the plugin. Total session-start context tax: ~150 tokens (one skill description), not ~1000 (the naive design with five separate skills). 6× reduction. Internal "agents" are PROMPTS fed to background `claude -p` processes by the dispatcher script — they never appear in the Skill router and never tax session start.

```
skills/om-orchestrate/
├── SKILL.md                                # ~80 lines, just enough for routing
├── references/                             # loaded on-demand, zero session tax
│   ├── agent-contracts.md
│   ├── claim-protocol.md
│   ├── dispatcher.md
│   ├── failure-recovery.md
│   ├── orchestration-yml.md
│   └── bootstrap.md
├── prompts/                                # fed to claude -p at runtime, never loaded as skills
│   ├── coding-agent.md
│   ├── e2e-agent.md
│   └── merge-agent.md
└── scripts/
    └── dispatcher.sh                       # the bash wrapper
```

#### Subcommands

- `/om-orchestrate init` — bootstrap UX. Writes `.ai/orchestration.yml`, creates the 11 status labels, verifies `gh auth`. Idempotent.
- `/om-orchestrate run [<app-spec>]` — start the dispatcher. Spawns one e2e singleton + one coding agent (Phase 1; raises to N in Phase 2). Runs until queue drains.
- `/om-orchestrate status` — read-only state report.
- `/om-orchestrate stop` — graceful shutdown.

#### Key design decisions baked into v1.12.0

- **Issues, not PRs, are work units.** Earlier draft used PRs; Issues are a strict upgrade because the work exists from decomposition (before any code), failed PRs don't muddy state (issue stays open, new PR can be linked), and dependencies use the well-known `Blocked by #N` idiom.
- **Claim protocol uses single-instance `claim:agent-<ts>-<pid>-<host>` label + verify-after-add + lowest-timestamp tiebreaker.** GitHub does NOT return 422 on duplicate `--add-assignee` (assignees are additive); the v0.1 spec assumed wrong. The corrected primitive is race-safe sub-second.
- **Dispatcher is a bash wrapper (`scripts/dispatcher.sh`), not a long-running claude session.** Coding agents are short-lived per-tick `claude -p` processes. E2E singleton is the one long-lived `/loop` process. Stateless beyond GitHub labels — the dispatcher (or any agent) can be killed and recovers.
- **Project-agnostic via `.ai/orchestration.yml`.** Every adopting OM project declares its own e2e command, required env, merge strategy, base branch, parallel_n, etc. No hardcoded PRM-specific assumptions. Community-fit by design.
- **Auto-merge ships in Phase 1.** Trivial when only one PR is in flight (no conflict possible). Pulled forward so v1.14.0 doesn't have to add it. Multi-PR conflict auto-rebase ships in Phase 2 (v1.13.0).
- **Cost telemetry instrumented from day 1.** Per-tick jsonl logs to `/tmp/om-telemetry/`. Phase 2 baseline measurement is therefore a deferred-but-easy step.

#### `om-implement-spec` Step 8 — additive singleton-detect fallback

`om-implement-spec` Step 8 (Verification → Integration tests) is patched additively. When ready for tests, the implementer detects whether an e2e singleton is alive (`.ai/orchestration.yml` exists + `/tmp/om-agent-e2e.pid` names a live process + recent e2e comment posted). If alive → enqueue via `status:coding → status:needs-e2e` label transition + lean handoff comment, exit. If not alive → fall back to inline `yarn test:integration:ephemeral` (current v1.11.6 behavior). Three positive signals required to enqueue; false positives unacceptable; false negatives recoverable.

**BC**: nothing breaks for users who haven't run `/om-orchestrate init`. Identical v1.11.6 behavior in inline path.

### Bundled — lean GitHub language (formerly v1.11.7)

The lean GitHub communication style codification was originally planned as v1.11.7. Per the context-budget rule and to avoid release-ceremony churn, it ships AS PART OF v1.12.0:

- **`om-auto-create-pr` Step 12** — verbose "comprehensive summary comment" template (~50 lines with stat tables, file lists, §-citations, internal skill names) replaced with a 6-line lean template: run plan path + status + plain-English what-changed + verification one-liner + rollback note. No stat tables, no SHA dumps, no internal jargon.
- **`om-auto-continue-pr` Step 8** — same shape rewrite for resume comments. Same 6-line lean template.
- **`om-auto-review-pr` Step 11** — completion comment tightened to one short line. Verdict + findings live in the formal review body (step 8), not duplicated into the completion comment.
- All three skills now MUST NOT paste secrets, env var values, raw test output, or unredacted stack traces in any comment. (The rule existed in `auto-continue-pr`'s Rules block; v1.12.0 standardizes it across the trio.)

Pre-v1.11.7 PRs in any repo retain their verbose comments as historical record — no retroactive rewriting.

### Files touched

- `skills/om-orchestrate/SKILL.md` (new) — ~80 lines, the only new top-level skill.
- `skills/om-orchestrate/references/{bootstrap,orchestration-yml,dispatcher,agent-contracts,claim-protocol,failure-recovery}.md` (new × 6) — on-demand references; zero session-start cost.
- `skills/om-orchestrate/prompts/{coding-agent,e2e-agent,merge-agent}.md` (new × 3) — content fed to background `claude -p` processes; not skills.
- `skills/om-orchestrate/scripts/dispatcher.sh` (new) — bash wrapper that spawns the fleet.
- `skills/om-implement-spec/SKILL.md` — Step 8 patched additively with singleton-detect fallback.
- `skills/om-auto-create-pr/SKILL.md` — Step 12 verbose template replaced with lean version.
- `skills/om-auto-continue-pr/SKILL.md` — Step 8 verbose template replaced with lean version.
- `skills/om-auto-review-pr/SKILL.md` — Step 11 completion comment tightened.
- `README.md` — bumped from "18 user-facing skills" to "19" + new entry in Automation table + v1.12.0 callout.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version 1.12.0.
- `CHANGELOG.md` — this entry.

### Phasing toward v1.14.0 oneshot goal

| Phase | Version | Surface |
|---|---|---|
| **Phase 1 (this release)** | v1.12.0 | E2E singleton + label vocabulary + bootstrap UX + auto-merge for single-agent + lean language. **Validation surface: PRM Spec #6 single-agent end-to-end through auto-merge.** |
| Phase 2 | v1.13.0 | Multi-agent coding (parallel_n > 1) + claim protocol race-safety + multi-PR conflict auto-rebase + cost baseline measurement. **Validation: PRM Spec #6 + #7 in parallel.** |
| Phase 3 | v1.14.0 | Full failure recovery (machine-reboot, dispatcher crash, mid-merge crash) + GitHub Projects v2 status field + kanban view for humans. **v1.14.0 = oneshot-complete.** |

### Process notes (lessons)

- The `om-orchestrate` skill avoids the trap of "5 new skills for orchestration" by treating internal agents as prompts (fed to `claude -p`) and workflow detail as references (loaded on-demand). New rule for any future orchestration extensions: at most ONE new top-level skill per architectural concern. Captured as a feedback memory.
- Bundling v1.11.7's lean-language codification into v1.12.0 saves a release-ceremony round and demonstrates that small refactors don't always need their own version bump — they ship with the next behavior change that needs them.
- The pre-implementation analysis (`docs/specs/analysis/ANALYSIS-2026-05-07-github-tasks-orchestration.md`) caught 4 critical issues in the v0.1 spec before any code was written. Continue this discipline for future major specs — Piotr's spec-readiness gate is cheap and high-value.

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

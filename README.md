# om-superpowers

Claude Code plugin for [Open Mercato](https://github.com/open-mercato/open-mercato) developers. 19 user-facing skills covering the full OM lifecycle — from business requirements through implementation to code review to autonomous parallel orchestration. Specialist sub-tasks (pre-implementation analysis, module ejection, toolkit audit, agent contracts) are demoted to references under their natural parent skills and load on demand.

## Install

```
/plugins marketplace add SHGrowth/om-superpowers
/plugins install om-superpowers@om-superpowers
```

### Prerequisites

- [Claude Code](https://claude.ai/code) (CLI or Desktop)
- [GitHub CLI](https://cli.github.com/) (`gh`) — used by `om-cto` for platform search

```bash
gh auth login          # one-time setup
gh auth status         # verify you're authenticated
```

### Update

```
/plugins marketplace update om-superpowers
```

## Getting Started

### Ideation & spec writing (no app needed)

Create a project directory and start Claude Code:

```bash
mkdir my-project && cd my-project
mkdir app-spec
claude
```

The `app-spec/` directory tells the plugin to activate. Then just describe what you want to build:

> "I want to build a B2B portal for selling Apple devices to enterprises"

The plugin works through **personas** — real engineering thinkers whose decision-making style Claude already knows deeply:

| Persona | Role | Based on |
|---------|------|----------|
| **Cagan** | Product Manager — requirements, workflows, user stories | Marty Cagan, author of *Inspired* |
| **Piotr** | CTO — architecture, gap analysis, implementation | Piotr Karwatka, OM CTO (1,400+ contributions) |
| **Krug** | UX Reviewer — navigation, cognitive load, task flow | Steve Krug, author of *Don't Make Me Think* |
| **Vernon** | Domain Challenger — validates domain model integrity | Vaughn Vernon, author of *Implementing DDD* |

Each persona brings a distinct perspective. They challenge each other — Cagan defines what to build, Vernon challenges the domain model, Piotr maps it to the platform, Krug reviews the UI. The pipeline runs them in sequence:

1. **Cagan** walks you through business requirements — who are the users, what are the workflows, what does success look like. Outputs an App Spec.
2. **Piotr** decomposes the App Spec into functional specs — one per module or feature. You review and approve them.
3. **Piotr** implements each spec one by one — writes code, runs tests, does code review — and checkpoints with you between each spec so you can test on localhost.

You can also invoke any skill directly, outside the pipeline:

- **"does OM already handle inventory?"** → `om-cto` does a platform gap analysis
- **"extend the customer table with a VIP flag"** → `om-system-extension` guides the UMES approach
- **"this page is broken"** → `om-troubleshooter` diagnoses the issue
- **"run integration tests"** → `om-integration-tests` executes the Playwright suite

### Building an app

When you're ready to code, scaffold the OM app into the same directory:

```bash
npx create-mercato-app@develop .
yarn install
rm -rf .ai/skills/
```

> Use the `@develop` tag to get the latest modules and templates. The `rm -rf .ai/skills/` removes frozen skill copies that the plugin replaces — this step will no longer be needed once [open-mercato/open-mercato#1562](https://github.com/open-mercato/open-mercato/pull/1562) is merged.

Your `app-spec/` stays in place. The pipeline continues where you left off — Piotr picks up the approved specs and starts implementing.

### Codex CLI

Codex does not support Claude Code plugins natively. To use OM skills in Codex:

1. Copy `skills/` into your project's `.agents/skills/`
2. Copy `om-reference/` into your project root
3. Skills that use the `Skill` tool will need manual invocation

## How It Works

The plugin auto-detects OM projects on session start by checking for any of: `@open-mercato/` in `package.json`, `"Open Mercato"` in `AGENTS.md`, `.ai/` directory, or `app-spec/` directory. When detected, all skills are injected into the session.

### Two Workflows

**Manual (skill-by-skill):** Invoke any skill directly — `om-troubleshooter`, `om-system-extension`, etc.

**Orchestrated (autonomous):** Start with `om-product-manager` to define requirements, then `om-cto` takes over — writes specs, implements them, runs tests, does code review, and checkpoints with you between each spec.

```
        Manual                                  Orchestrated
     (pick any skill)                     (autonomous pipeline)

    ┌─────────────────┐              ┌─────────────────────────┐
    │  om-cto         │              │  om-product-manager     │
    │  (gap analysis) │              │  (App Spec with Cagan)  │
    ├─────────────────┤              └───────────┬─────────────┘
    │  om-troubleshoot│                          │
    │  (fix errors)   │                          ▼
    ├─────────────────┤              ┌─────────────────────────┐
    │  om-system-ext  │              │  om-cto                 │
    │  (extend UMES)  │              │  Spec Orchestrator:     │
    ├─────────────────┤              │  decompose → write specs│
    │  om-integration │              │  → cross-validate       │
    │  -tests (QA)    │              │  → execution plan       │
    ├─────────────────┤              │  → you review           │
    │  ...any skill   │              └───────────┬─────────────┘
    └─────────────────┘                          │ (per spec)
                                                  ▼
                                      ┌─────────────────────────┐
                                      │  om-cto                 │
                                      │  Implementation Orch:   │
                                      │  implement → test →     │
                                      │  code review → you test │
                                      │  on localhost → next    │
                                      └─────────────────────────┘
```

## Skills

### Spec & Design

| Skill | When to use |
|-------|-------------|
| `om-product-manager` | Defining business requirements — BEFORE any spec or code exists |
| `om-cto` | Gap analysis, architecture decisions, orchestrating the full spec-to-build pipeline, pre-impl BC/risk analysis, or auditing the skill corpus |
| `om-ux` | UI architecture review — navigation, task completion, cognitive load |
| `om-spec-writing` | Writing a functional specification with architectural compliance |

### Implementation

| Skill | When to use |
|-------|-------------|
| `om-implement-spec` | Multi-phase spec implementation with coordinated subagents |
| `om-module-scaffold` | Bootstrapping a new module from scratch (entity, API, pages, ACL) |
| `om-data-model-design` | Entity design, relationships, migration lifecycle |
| `om-system-extension` | Extending core modules via UMES (enrichers, widgets, interceptors, guards) — also handles ejection as a last-resort path |
| `om-integration-builder` | Building provider packages (payment, shipping, data sync) |
| `om-backend-ui-design` | Backend UI pages within the OM component library |

> **As of v1.11.6**, `om-implement-spec` runs a mandatory **post-PR review gate** (Step 9) before reporting a spec implementation complete. After the run plan opens a PR, the implementer invokes `om-auto-review-pr <PR#>` in autofix mode (which itself chains `om-ds-guardian REVIEW` for UI work) and loops until clean verdict or only non-actionable findings remain. This closes the gap that caused PRM PR #4 + PR #5 to ship without code review or DS-Guardian passes — both required user-initiated cleanup loops surfaced only when the user asked *"have we run tests, ui tests, design system review, code review?"* Step 6 self-review is the implementer reading the checklist to itself; Step 9 is the real review. Rationale and forensic in [`docs/specs/2026-05-07-implement-spec-post-pr-gate.md`](docs/specs/2026-05-07-implement-spec-post-pr-gate.md).

> **As of v1.12.1**, suspected Open Mercato core (`@open-mercato/*`) bugs no longer get silent workarounds. Any om-superpowers agent that finds itself thinking *"OM is broken, let me work around it"* MUST route through `om-cto/references/upstream-bug-triage.md` before patching. om-cto verifies the bug, returns a verdict (`not-a-bug` / `already-reported` / `confirmed-new-bug`), classifies the proposed workaround size (**minor**: ≤50 LOC + single file + no abstraction leakage → apply+file upstream issue+file downstream removal-trigger task; **major**: anything else → wait-for-upstream + file blocker + stop+report to user), and drafts the upstream + downstream ticket bodies. The calling agent does the actual `gh issue create` filings and applies the patch (or stops). Workaround code MUST contain a marker comment of the form `// remove when @open-mercato/<pkg>#<N> ships`; `om-code-review` flags missing markers + missing upstream issue + missing downstream task as **Critical**. The rule applies to `om-troubleshooter`, `om-auto-create-pr`, `om-auto-continue-pr`, `om-system-extension`, `om-code-review`, and the `om-orchestrate` coding-agent. Reason: silent workaround accumulation hides real bugs from the OM core team, and major workarounds taken without user input become permanent because no one remembers they were temporary. Implemented as an on-demand reference inside `om-cto` per the v1.12.0 surface-budget rule — no new top-level skill.

> **As of v1.15.0**, the upstream-bug-triage flow closes its loop with a **producer-consumer convention** the model executes with native tools — no CLI wrapper. When triage's verdict is `confirmed-new-bug` AND a fix in OM core is on the table, the calling consumer-app session does NOT author the upstream patch inline. Instead: (1) `Read` `~/.config/om-superpowers/handoff.json`'s `om_core_path` key, asking the user once and `Write`-ing the config if missing; (2) compose substance and `Write` `<om-core-checkout>/agents/tasks/YYYY-MM-DD-<slug>/README.md` with the template inline in `skills/om-cto/references/upstream-bug-triage.md` (`<om-core-checkout>` placeholder kept literal in the README's example commands so the drain agent on a different machine doesn't see a stale absolute path); (3) stop the upstream-patch portion of the task and report the folder path to the user. A separate session running with `cwd` inside the OM checkout drains the queue per the new `skills/om-cto/references/upstream-task-drain.md` (claim by `git mv` to `in-progress/`, re-verify anchors → branch off `origin/main` → patch + tests → PR to your fork, `git mv` to `done/` with sibling `resolution.md` linking the merged PR back to the originating downstream task). A `bin/om-handoff` + `bin/om-task-list` wrapper pair was drafted earlier in the day and **deleted before commit** after Musk-Step-1 review: five wrapper jobs all reduced to native primitives, the skeleton-then-Edit pattern inverted the friction goal (two round trips vs. one `Write`), and two BLOCKERs (heredoc leaking the producer-local path into the README; wrapper not on `$PATH` from consumer-app session) only existed because the wrapper existed — see `docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline-v2.md` for the reasoning. The PreToolUse cwd-jail lockdown-hook alternative was rejected separately. Empirical baseline (`docs/specs/analysis/ANALYSIS-2026-05-10-upstream-handoff-baseline.md`) mining 16 cross-project handoff writes since 2026-04-01 found a 67% binding rate without any rule — consumer-app sessions are willing to use the queue, the convention just makes the path explicit. Plan B (`SessionEnd` git-diff auditor scanning for `patches.diff` writes from non-OM `cwd`) deferred to 1.15.1 if Plan A measurement shows binding-rate <90%. The drain protocol is a sibling reference under `om-cto`, not a new top-level skill, per the surface-budget rule.

> **As of v1.12.0**, the new **`om-orchestrate`** skill (Phase 1 of the road to v1.14.0 oneshot OM systems) ships a singleton-mode autonomous fleet. Run `/om-orchestrate init` to bootstrap any OM repo (writes `.ai/orchestration.yml`, creates 11 status labels, verifies `gh auth`), then `/om-orchestrate run <app-spec>` to spawn one e2e singleton + one coding agent that runs through the full pipeline (claim issue → code → enqueue tests → resume → review → **auto-merge**). All coordination via GitHub Issues + labels + PR comments. No filesystem queue, no cmux ceremony. The agent prompts (`prompts/coding-agent.md`, `prompts/e2e-agent.md`) are NOT registered as skills — they're content the dispatcher feeds to background `claude -p` processes, costing zero session-start context. Total session-start tax for the entire orchestration system: one new skill description (~150 tokens). v1.12.0 also bundles **lean GitHub language** retroactively across `om-auto-create-pr`, `om-auto-continue-pr`, `om-auto-review-pr` summary comment templates — plain English, point at run plan / spec, no stat tables, no SHA dumps. `om-implement-spec` Step 8 patched additively with singleton-detect-and-fallback so non-orchestration users see identical v1.11.6 behavior. v1.13.0 raises `parallel_n` for multi-agent; v1.14.0 closes the loop with full failure recovery + Projects v2 view. Design spec in [`docs/specs/2026-05-07-github-tasks-orchestration.md`](docs/specs/2026-05-07-github-tasks-orchestration.md); pre-impl analysis in [`docs/specs/analysis/ANALYSIS-2026-05-07-github-tasks-orchestration.md`](docs/specs/analysis/ANALYSIS-2026-05-07-github-tasks-orchestration.md).

### Quality & Testing

| Skill | When to use |
|-------|-------------|
| `om-code-review` | CI/CD verification gate with full OM compliance checklist |
| `om-integration-tests` | Creating or running Playwright integration tests |
| `om-troubleshooter` | Diagnosing errors, 404s, missing modules, broken widgets |
| `om-ds-guardian` | Design-system compliance — runs automatically inside auto-review-pr and scaffolders |

> **As of v1.13.0**, `om-ds-guardian` keeps its references in sync with upstream OM via a manual sync script (`node scripts/sync/ds.mjs`). The script mirrors `.ai/ds-rules.md` + `.ai/ui-components.md` into `om-reference/.ai/`, source-extracts 11 specialized inputs (TagsInput, ComboboxInput, DatePicker, DateTimePicker, EventPatternInput, EventSelect, LookupSelect, PhoneNumberField, SwitchableMarkdownInput, TimeInput, TimePicker) into `references/specialized-inputs.md`, and runs a discovery scan that surfaces new/removed/changed upstream files as action items in `sync-reports/YYYY-MM-DD.md`. Pinned to a single upstream commit SHA per run, idempotent, dry-run via `--dry-run`, loud failures, smoke tests against mirrored content. Closes the **TagsInput drift bug** found while reviewing PRM `caseStudyForm.tsx` — DS Guardian REVIEW silently accepted `<Input value="comma,separated,slugs">` because the skill's hand-curated references never mentioned `TagsInput` even though it shipped in upstream `@open-mercato/ui` long ago and is used in 10+ core call-sites. Upstream issue tracking the canonical doc gap: [open-mercato/open-mercato#1874](https://github.com/open-mercato/open-mercato/issues/1874). The new **mirrors-docs** relationship in `UPSTREAM.md` generalizes the pattern — future shadowing skills (om-data-model-design, om-system-extension, om-module-scaffold, om-backend-ui-design) can adopt the same shape (manifest + discovery + extract + smoke test + report) when their upstream canonical docs land.

> **As of v1.14.0**, `bin/claude-validated` ships as opt-in tooling — a structural wrapper around `claude -p` (headless mode) that runs 5 deterministic regex checks against output and rejects+retries on fabrication-shape violations: `#1` percentages without N/M fraction, `#2` English hedges (`approximately`/`around`/`roughly`/`~[0-9]`), `#3` persona invocations (`Piotr`/`Cagan` as authority labels), `#4` Polish hedges (`szacunkowo`/`około`/`mniej więcej`/`w przybliżeniu` — locale-restrictive: forces English output regardless of input language), `#5` effort estimates without per-item enumeration. Drives toward exit 0 with grounded answer (within 2-retry budget) OR exit 1 with named FAIL on stderr — silent fabrication is no longer an option for "does platform X cover capability Y" prompts in headless mode. Driven by S008 → S010 → S011: 16 data points across 4 progressively-tightened text-channel gates (HARD-GATE prose, `## Sources` mandate, Phase 6 doubt-check, ROUTING CHECK) plus one deletion experiment (Replace Advisory with Research Plan), all empirically established that prose rules in skill bodies do not bind `claude -p` for fabrication-shape failures. Skill text is advisory; the wrapper's regex is normative. Opt-in: `echo "<question>" | ~/Documents/om-superpowers/bin/claude-validated --model claude-opus-4-7`, or symlink to PATH. Not in scope: interactive Claude Code, Claude Desktop, plain `claude` without `-p` (post-emit by design — for interactive enforcement, Claude Code hooks would be needed; option (b) from S011, deferred). Bundled with: `om-cto/SKILL.md` persona-prune (drops `# Piotr` H1 + persona narrative + `Red Flags` Piotr-says table; empirical chain probe 3 → S011 named these the load-bearing fabrication-shield surfaces). Cross-refs: `agents-master/improvements/I018.md`, `sessions/S011.md`.

### Automation

| Skill | When to use |
|-------|-------------|
| `om-auto-create-pr` | Automatically create a pull request from current changes |
| `om-auto-review-pr` | Automatically review an open pull request |
| `om-auto-continue-pr` | Continue work on an existing pull request |
| `om-orchestrate` | **(v1.12.0)** Run a fully autonomous parallel agent fleet that ships OM apps end-to-end via GitHub Issues + PRs. Subcommands: `init`, `run`, `status`, `stop`. Phase 1 of the road to oneshot OM systems (v1.14.0). |

> **As of v1.10.0**, `om-auto-create-pr` and `om-auto-continue-pr` enforce a **tests-with-code gate** at commit time: any commit that stages source code (`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` outside `__tests__/` and not matching `*.test.*` / `*.spec.*`) without test files is blocked. The agent then either adds tests in the same commit or splits the staged set. Rationale and exemptions in [`docs/specs/2026-05-06-test-coverage-at-commit.md`](docs/specs/2026-05-06-test-coverage-at-commit.md); baseline data that drove the scope in [`docs/specs/2026-05-06-ralph-loop-baseline.md`](docs/specs/2026-05-06-ralph-loop-baseline.md).

> **As of v1.11.0**, on session start the plugin auto-detects in-progress runs in `.ai/runs/`, approved specs in `.ai/specs/`, or `app-spec/` ideation state, and injects a specific actionable command into the agent's context. Vague prompts like "continue" or "finish this" route to the right skill instead of ad-hoc Bash. See [hooks/session-start](hooks/session-start) for the detection logic.

> **As of v1.11.2**, the tests-with-code gate also fires on `om-auto-review-pr` autofix commits. Three entry points (create / continue / review-autofix), one gate, same shape.

> **As of v1.11.3**, duplicate-work prevention runs in two layers. The SessionStart hook calls `gh pr list` and surfaces any open PR whose body contains a `Tracking plan:` line — so plans on other branches (invisible to the local `.ai/runs/` scan) become visible at session start. `om-auto-create-pr` step 0 then runs a keyword-overlap check (`gh pr list --search "<spec/module> in:title,body"`) before claiming a slug; on match, the skill stops and asks the user via `AskUserQuestion` whether to resume the existing PR via `om-auto-continue-pr`, proceed in parallel, or abort. Soft surfacing + hard enforcement, layered.

#### Autonomous Ralph-style runs

For unattended end-to-end execution against an in-progress PR, use Claude Code's harness `/loop` skill — no custom wrapper needed:

```
/loop 5m /auto-continue-pr 1796
```

Each iteration starts cold (clean context). The v1.11.0 SessionStart hook detects the in-progress plan and routes to `om-auto-continue-pr`, which runs the tests-with-code gate per atomic commit. The loop exits when you stop it or when the plan has no unchecked steps left and the PR flips to `complete`. Mirrors the [Ralph pattern](https://github.com/snarktank/ralph) without shelling out to fresh `claude -p` processes — the harness handles iteration. For one-off scheduled runs, use `/schedule` instead.

> **As of v1.11.5**, do **NOT** use `/loop` *self-paced* (no interval) for chained autonomous coding. Self-pace mode wires the agent to call `ScheduleWakeup`, whose tooltip default for "idle ticks" is **1200–1800 s** (20–30 min). With an unchecked run-plan checklist there is nothing to wait for, so each "tick" inserts a multi-minute do-nothing gap between commits, and the agent will fabricate a cache-warmth rationale that contradicts the 5-min cache TTL. The two correct patterns are: **(a)** `/loop 5m /auto-continue-pr <PR#>` (cron mode, fixed interval, fresh context per turn) for unattended runs, or **(b)** a single long conversation that chains checklist items without sleeping. Triggered by patryk-standalone session forensic 2026-05-07 — see [`docs/specs/2026-05-07-autonomous-loop-policy.md`](docs/specs/2026-05-07-autonomous-loop-policy.md).

### Meta

| Skill | When to use |
|-------|-------------|
| `om-user-proxy` | User's decision proxy — resolves questions from context, escalates only business judgment calls |

### Demoted to references (loaded on demand by their parent)

These specialist tools are not user-invocable as top-level skills. The parent skill loads them when needed:

| Reference | Parent | When the parent loads it |
|-----------|--------|--------------------------|
| `om-cto/references/pre-impl-analysis.md` | `om-cto` | Pre-implementation BC/risk audit at the spec→impl gate |
| `om-system-extension/references/eject.md` | `om-system-extension` | When UMES extensions are insufficient and ejection is required |
| `om-cto/references/toolkit-audit.md` | `om-cto` | Auditing the skill corpus for context waste or trigger overlap |

## Architecture

Skills are lightweight — decision logic and workflows inline, reference material in `references/` loaded on-demand. Rules from the OM platform's own `AGENTS.md` files are vendored in `om-reference/` and referenced directly, never duplicated.

```
skills/
  om-cto/
    SKILL.md                          # Task router (~4 KB)
    references/
      advisory.md                     # Gap analysis workflow (on-demand)
      spec-orchestrator.md            # App Spec → functional specs (on-demand)
      impl-orchestrator.md            # Specs → implementation (on-demand)
      ...
  om-system-extension/
    SKILL.md                          # Decision tree + mechanism summaries (~12 KB)
    references/
      extension-templates.md          # Full code templates (on-demand)
      extension-contracts.md          # Type definitions (on-demand)
  ...

om-reference/                         # Vendored from open-mercato/open-mercato
  AGENTS.md                           # Root platform conventions
  packages/                           # Per-package AGENTS.md files
```

### Skill Syncing

Some skills are synced from the upstream [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato) repo. A [daily CI workflow](.github/workflows/sync-om-skills.yml) checks for changes, bumps the patch version, and opens a PR for review.

To sync manually:

```bash
bash scripts/sync-om-skills.sh
git diff skills/
git add skills/ om-reference/ && git commit -m "chore: sync OM skills from upstream"
```

### Custom vs Synced Skills

| Type | Skills | Maintained in |
|------|--------|---------------|
| **Custom** | om-product-manager, om-cto, om-ux, om-user-proxy, om-auto-create-pr, om-auto-continue-pr, om-auto-review-pr | This repo |
| **Synced** | All others (top-level skills + demoted references — see `scripts/sync-om-skills.sh` for the full mapping including `DEMOTED_SKILL_PAIRS`) | [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato) |

The auto-* trio forked from upstream across two releases to land the **tests-with-code gate** at every commit point: v1.10.0 added it to `om-auto-create-pr` step 6 and `om-auto-continue-pr` step 4; v1.11.2 added it to `om-auto-review-pr`'s autofix loop after a session forensic showed autofix commits were bypassing the gate. See `docs/specs/2026-05-06-test-coverage-at-commit.md` for the spec.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes — follow the existing skill structure (`SKILL.md` + `references/`)
4. Open a pull request

For synced skills, contribute upstream to [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato) instead.

## License

MIT

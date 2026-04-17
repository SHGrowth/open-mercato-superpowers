# om-superpowers

Claude Code plugin for [Open Mercato](https://github.com/open-mercato/open-mercato) developers. 20 skills covering the full OM lifecycle — from business requirements through implementation to code review.

## Install

```
/plugins marketplace add SHGrowth/om-superpowers
/plugins install om-superpowers@om-superpowers
```

### Prerequisites

- [Claude Code](https://claude.ai/code) (CLI or Desktop)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated, used by `om-cto` for platform search

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

When you're ready to code, scaffold an OM app:

```bash
npx create-mercato-app@develop my-app
cd my-app
yarn install
```

> Use the `@develop` tag to get the latest modules and templates.

Remove frozen skill copies — the plugin replaces them with 20 always-up-to-date skills:

```bash
rm -rf .ai/skills/
```

> This cleanup step will no longer be needed once [open-mercato/open-mercato#1562](https://github.com/open-mercato/open-mercato/pull/1562) is merged.

Start Claude Code in the app directory. If you already have an `app-spec/` from the ideation phase, copy it into the app so the pipeline continues where you left off.

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
| `om-cto` | Gap analysis, architecture decisions, or orchestrating the full spec-to-build pipeline |
| `om-ux` | UI architecture review — navigation, task completion, cognitive load |
| `om-spec-writing` | Writing a functional specification with architectural compliance |
| `om-pre-implement-spec` | Pre-implementation backward-compatibility and risk analysis |

### Implementation

| Skill | When to use |
|-------|-------------|
| `om-implement-spec` | Multi-phase spec implementation with coordinated subagents |
| `om-module-scaffold` | Bootstrapping a new module from scratch (entity, API, pages, ACL) |
| `om-data-model-design` | Entity design, relationships, migration lifecycle |
| `om-system-extension` | Extending core modules via UMES (enrichers, widgets, interceptors, guards) |
| `om-eject-and-customize` | Ejecting a core module when UMES isn't enough |
| `om-integration-builder` | Building provider packages (payment, shipping, data sync) |
| `om-backend-ui-design` | Backend UI pages within the OM component library |

### Quality & Testing

| Skill | When to use |
|-------|-------------|
| `om-code-review` | CI/CD verification gate with full OM compliance checklist |
| `om-integration-tests` | Creating or running Playwright integration tests |
| `om-troubleshooter` | Diagnosing errors, 404s, missing modules, broken widgets |

### Automation

| Skill | When to use |
|-------|-------------|
| `om-auto-create-pr` | Automatically create a pull request from current changes |
| `om-auto-review-pr` | Automatically review an open pull request |
| `om-auto-continue-pr` | Continue work on an existing pull request |

### Meta

| Skill | When to use |
|-------|-------------|
| `om-user-proxy` | User's decision proxy — resolves questions from context, escalates only business judgment calls |
| `om-toolkit-review` | Auditing the skill corpus for context waste, duplication, stale references |

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
| **Custom** | om-product-manager, om-cto, om-ux, om-user-proxy, om-toolkit-review | This repo |
| **Synced** | All others (15 skills) | [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato) |

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes — follow the existing skill structure (`SKILL.md` + `references/`)
4. Open a pull request

For synced skills, contribute upstream to [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato) instead.

## License

MIT

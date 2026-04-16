# om-superpowers

Claude Code plugin for Open Mercato developers. 16 skills covering the full OM lifecycle — from business requirements through implementation to code review.

## Install

### Claude Code (CLI & Desktop)

```bash
# Install the plugin
/plugin marketplace add SHGrowth/om-superpowers

# If prompted, confirm installation
/plugin install om-superpowers@SHGrowth/om-superpowers
```

### Update to latest version

```bash
# Pull latest changes from GitHub
/plugin marketplace update SHGrowth/om-superpowers

# Reload without restarting the session
/reload-plugins
```

Auto-update is off by default for third-party plugins. Enable it in `/plugin` → **Marketplaces** tab.

### Codex CLI

Codex does not support Claude Code plugins natively. To use OM skills in Codex:

1. Copy the `skills/` directory into your project's `.agents/skills/` (Codex auto-discovers skills from this path)
2. Copy `om-reference/` into your project root (skills reference these for platform conventions)
3. Skills that use the `Skill` tool will need manual invocation — Codex doesn't have a skill tool equivalent

Alternatively, use the [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) to run Codex inside Claude Code sessions where OM skills are available.

### Prerequisites

- [Claude Code](https://claude.ai/code) (or Cursor with plugin support)
- [superpowers](https://github.com/obra/superpowers) plugin — OM skills reference superpowers workflows (brainstorming, writing-plans, executing-plans, TDD)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated, for om-cto platform search

## How It Works

The plugin auto-detects OM projects on session start by checking for `@open-mercato/` in `package.json`, "Open Mercato" in `AGENTS.md`, or an `.ai/` directory. When detected, all 16 skills are injected into the session.

### The Two Workflows

**Manual (skill-by-skill):** Invoke any skill directly — `om-code-review`, `om-troubleshooter`, etc.

**Orchestrated (autonomous):** Start with `om-product-manager` to define requirements, then `om-cto` takes over — autonomously writes specs, implements them one by one, runs tests, does code review, and checkpoints with you between each spec.

```
                        Manual                                  Orchestrated
                     (pick any skill)                     (autonomous pipeline)

                    ┌─────────────────┐              ┌─────────────────────────┐
                    │  om-cto         │              │  om-product-manager     │
                    │  (gap analysis) │              │  (App Spec with Cagan)  │
                    ├─────────────────┤              └───────────┬─────────────┘
                    │  om-code-review │                          │
                    │  (review code)  │                          ▼
                    ├─────────────────┤              ┌─────────────────────────┐
                    │  om-troubleshoot│              │  om-cto                 │
                    │  (fix errors)   │              │  Spec Orchestrator:     │
                    ├─────────────────┤              │  decompose → write specs│
                    │  om-integration │              │  → cross-validate       │
                    │  -tests (QA)    │              │  → execution plan       │
                    ├─────────────────┤              │  → you review           │
                    │  om-spec-writing│              └───────────┬─────────────┘
                    │  (write a spec) │                          │ (per spec)
                    ├─────────────────┤                          ▼
                    │  ...any skill   │              ┌─────────────────────────┐
                    └─────────────────┘              │  om-cto                 │
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
| `om-cto` | Gap analysis, architecture decisions, or orchestrating the full spec→build pipeline |
| `om-ux` | UI architecture review — navigation, task completion, cognitive load |
| `om-spec-writing` | Creating architecturally compliant specifications |
| `om-pre-implement-spec` | Pre-implementation backward compatibility and risk analysis |

### Implementation

| Skill | When to use |
|-------|-------------|
| `om-implement-spec` | Multi-phase spec implementation with coordinated subagents |
| `om-module-scaffold` | Bootstrapping a new module from scratch (entity → API → pages → ACL) |
| `om-data-model-design` | Entity design, relationships, migration lifecycle |
| `om-system-extension` | Extending core modules via UMES (enrichers, widgets, interceptors, guards) |
| `om-eject-and-customize` | Ejecting a core module when UMES isn't enough |
| `om-integration-builder` | Building provider packages (payment, shipping, data sync) |
| `om-backend-ui-design` | Backend UI pages within the OM component library |

### Quality

| Skill | When to use |
|-------|-------------|
| `om-code-review` | CI/CD verification gate + full OM checklist (20+ sections) |
| `om-integration-tests` | Creating or running Playwright integration tests |
| `om-troubleshooter` | Diagnosing errors, 404s, missing modules, broken widgets |

### Meta

| Skill | When to use |
|-------|-------------|
| `om-toolkit-review` | Auditing the skill corpus for context waste, duplication, stale refs |

## How superpowers + OM skills work together

Superpowers provides the **workflow engine** (brainstorming, planning, TDD, debugging). OM skills provide **domain knowledge** (what OM modules exist, how to review OM code, how to write OM specs). They interleave:

| Phase | Superpowers (how) | OM skills (what) |
|-------|-------------------|-------------------|
| Design | `brainstorming` | `om-product-manager`, `om-cto`, `om-ux` |
| Planning | `writing-plans` | `om-spec-writing`, `om-pre-implement-spec` |
| Implementation | `executing-plans`, `tdd` | `om-implement-spec`, `om-module-scaffold`, `om-system-extension`, `om-data-model-design`, `om-integration-builder`, `om-backend-ui-design` |
| Review | `requesting-code-review` | `om-code-review` (replaces generic reviewer) |
| Testing | `tdd` | `om-integration-tests` |
| Debugging | `systematic-debugging` | `om-troubleshooter` |

**Rule of thumb:** superpowers decides *how* to work. OM skills decide *what* to build and *what to check*.

## Architecture

Skills are lightweight — decision logic and workflows inline, code templates in `references/` loaded on-demand. Rules from the OM platform's own `AGENTS.md` are not duplicated in skills.

```
skills/
  om-cto/
    SKILL.md                          # Decision logic, phases, rules (~11KB)
    references/
      orchestrator-modes.md           # Detailed orchestrator workflows (on-demand)
      atomic-commits.md               # Scoring methodology (on-demand)
      context-loading.md              # Module lookup table (on-demand)
  om-system-extension/
    SKILL.md                          # Decision tree + mechanism summaries (~12KB)
    references/
      extension-templates.md          # Full code templates (on-demand)
      extension-contracts.md          # Type definitions (on-demand)
  ...
```

The vendored `om-reference/` directory contains the upstream OM platform's `AGENTS.md` files — the authoritative source for coding conventions. Skills reference these instead of inlining rules.

## Syncing OM platform skills

Some skills are vendored from [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato). To update:

```bash
bash scripts/sync-om-skills.sh
git diff skills/
git add skills/ && git commit -m "chore: sync OM skills from upstream"
```

## License

MIT

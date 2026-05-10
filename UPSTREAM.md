# Upstream skill lineage

om-superpowers is a layer on top of upstream skill plugins, not a replacement of them. This file tracks what each `om-*` skill builds on, what it inherits from upstream, what it inlines locally, and at which upstream version the inheritance was last reviewed.

Used to detect drift when an upstream plugin (most often [obra/superpowers](https://github.com/obra/superpowers)) changes a skill we extend. If the upstream change is a discipline upgrade, port it. If it's content swap that doesn't apply to OM, leave it and bump the reviewed-at marker.

## Relationship taxonomy

- **extends** — om skill uses the upstream discipline as its foundation, then adds an OM-specific layer (personas, spec format, OM rules, OM checklists). Upstream changes to the underlying discipline should be absorbed; upstream changes to prompts/examples usually shouldn't.
- **composes** — om skill orchestrates one or more upstream skills as steps in a larger OM-specific flow. Upstream changes propagate automatically *unless* the orchestration has inlined upstream logic.
- **mirrors-docs** — om skill is the downstream enforcer for upstream canonical *documentation* (not skill plugins). A per-skill sync script (e.g., `scripts/sync/ds.mjs`) pulls authoritative docs from upstream into `om-reference/` and may source-extract structured data (TypeScript types, JSDoc) into `skills/<name>/references/`. Drift = 0 by construction when sync is fresh; the skill layers ANALYZE/REVIEW/MIGRATE recipes on top.
- **independent** — no upstream counterpart. Upstream changes are irrelevant.

## Registry

Upstream pin format: `<plugin>@<version>`. `n/a` means the upstream plugin doesn't expose a version and the marker is "last reviewed by hand."

| om skill | rel | upstream | inherits | inlines | reviewed at |
|---|---|---|---|---|---|
| om-product-manager | extends | superpowers:brainstorming | iteration discipline, red-flag table, "before any creative work" gate | Cagan persona, business-requirements prompts, App Spec output format | superpowers@5.1.0 |
| om-implement-spec | extends | superpowers:executing-plans + subagent-driven-development | phase checkpointing, subagent dispatch pattern | OM phases (unit + integration + i18n + code-review), per-spec status updates; routes engineering-specialty references (module-scaffold, data-model-design, system-extension, integration-builder) on demand | superpowers@5.1.0 |
| om-code-review | extends | code-review:code-review | review rigor, evidence-before-assertion | OM compliance checklist (UMES, ACL, AGENTS.md, naming, security, anti-patterns) | code-review@n/a |
| om-troubleshooter | extends | superpowers:systematic-debugging | hypothesis loop, root-cause discipline | OM symptom→cause table, common error patterns (404s, missing modules, widgets) | superpowers@5.1.0 |
| om-auto-create-pr | composes | superpowers:requesting-code-review + finishing-a-development-branch | PR-creation discipline, branch hygiene | OM validation gate (typecheck/tests/i18n/build), label discipline, .ai/runs/ plan format | superpowers@5.1.0 |
| om-auto-review-pr | composes | superpowers:receiving-code-review + code-review:code-review | review-driving discipline, feedback discipline | gh integration, autofix loop, OM compliance checklist | superpowers@5.1.0 |
| om-auto-continue-pr | composes | superpowers:executing-plans | resume-from-checkpoint discipline | OM in-progress lock protocol, .ai/runs/ plan resumption | superpowers@5.1.0 |
| om-cto | independent | — | — | OM persona/orchestrator (Piotr); routes demoted references: pre-impl-analysis, toolkit-audit, spec-writing/, user-proxy.md | — |
| om-product-manager | independent (also extends brainstorming) | — | — | Cagan persona for App Spec authoring | — |
| om-ux | independent | — | — | OM IA review (Krug persona) | — |
| om-integration-tests | independent | — | — | OM Playwright suite | — |
| om-ds-guardian | mirrors-docs | open-mercato:.ai/ds-rules.md + .ai/ui-components.md (+ source-extract from packages/ui/src/backend/inputs/) | DS foundation tokens, primitive contracts (mirrored to `om-reference/.ai/`), specialized input surface (source-extracted to `references/specialized-inputs.md`) | ANALYZE/PLAN/MIGRATE/REVIEW/REPORT capabilities, enforcement scripts, decision tables, skill-curated migration recipes; routes the demoted backend-ui-design reference on demand | open-mercato@b39fb4d |

## Demoted skills (loaded as references under a parent)

Demoted skills are no longer top-level user-facing entries. The parent's SKILL.md announces the reference and routes to it on demand via Task Router. Two delivery modes:

- **Auto-synced** — upstream content is fetched by `scripts/sync-om-skills.sh` (the `DEMOTED_SKILL_PAIRS` list and `sync_demoted_skill()` function); frontmatter is stripped on write.
- **Frozen snapshot (v1.16.0)** — upstream content was vendored once at v1.16.0 release time and is now maintained manually. Manual cherry-pick required when upstream changes. Decision rationale: extending `sync_demoted_skill()` to walk nested `references/` folders was deferred in favor of cleaner script and lower per-sync risk.

| Demoted name | Parent | Reference path | Source mode | Reviewed at |
|---|---|---|---|---|
| pre-implement-spec | om-cto | `om-cto/references/pre-impl-analysis.md` | Auto-synced — `.ai/skills/pre-implement-spec` | open-mercato@(see `skills/.om-sync-version`) |
| toolkit-review | om-cto | `om-cto/references/toolkit-audit.md` | Maintained in this repo (custom, not synced) | n/a |
| spec-writing | om-cto | `om-cto/references/spec-writing/spec-writing.md` + 3 sub-refs | Frozen snapshot — was `.ai/skills/spec-writing` | open-mercato@7c10ccc (v1.16.0) |
| user-proxy | om-cto | `om-cto/references/user-proxy.md` | Maintained in this repo (custom, not synced) | n/a |
| module-scaffold | om-implement-spec | `om-implement-spec/references/module-scaffold/` (4 files) | Frozen snapshot — was `packages/create-app/agentic/shared/ai/skills/module-scaffold` | open-mercato@7c10ccc (v1.16.0) |
| data-model-design | om-implement-spec | `om-implement-spec/references/data-model-design/` (3 files) | Frozen snapshot — was `packages/create-app/agentic/shared/ai/skills/data-model-design` | open-mercato@7c10ccc (v1.16.0) |
| system-extension | om-implement-spec | `om-implement-spec/references/system-extension/` (4 files incl. eject.md) | Frozen snapshot — was `packages/create-app/agentic/shared/ai/skills/system-extension` | open-mercato@7c10ccc (v1.16.0) |
| eject-and-customize | om-implement-spec | `om-implement-spec/references/system-extension/eject.md` | Auto-synced — `packages/create-app/agentic/shared/ai/skills/eject-and-customize` (parent path updated in v1.16.0) | open-mercato@(see `skills/.om-sync-version`) |
| integration-builder | om-implement-spec | `om-implement-spec/references/integration-builder/` (3 files) | Frozen snapshot — was `.ai/skills/integration-builder` | open-mercato@7c10ccc (v1.16.0) |
| backend-ui-design | om-ds-guardian | `om-ds-guardian/references/backend-ui-design/` (2 files) | Frozen snapshot — was `.ai/skills/backend-ui-design` | open-mercato@7c10ccc (v1.16.0) |

## Drift check workflow (manual, until automated)

1. Determine the currently-installed upstream version:
   ```
   ls ~/.claude/plugins/cache/claude-plugins-official/superpowers/
   ```
2. For each row in this file with `rel` ∈ {extends, composes}, compare the `reviewed at` pin against the installed version. If it changed:
   ```
   diff -r \
     ~/.claude/plugins/cache/claude-plugins-official/superpowers/<old>/skills/<upstream-skill>/ \
     ~/.claude/plugins/cache/claude-plugins-official/superpowers/<new>/skills/<upstream-skill>/
   ```
3. For each upstream change, decide:
   - **Discipline upgrade** (new red-flag check, new step in the loop, new safety rule) → port into the matching om-* skill, bump `reviewed at`.
   - **Content change** (different prompt wording, different examples, plugin-specific glue) → ignore, just bump `reviewed at` to mark "reviewed, intentionally not absorbing."
4. Commit with a clear message: `chore: review upstream <plugin>@<version>, port <change> into <om-skill>` or `chore: review upstream <plugin>@<version>, no changes absorbed`.

## When to upgrade to automated sync

Build the automated diff/PR pipeline once we have evidence it pays off — i.e., after we've absorbed at least 2–3 real discipline upgrades from upstream and the manual workflow above is the bottleneck. Until then, the manifest is enough.

# OM Context Loading Strategy

## OM Repository

```
OM_REPO=~/Documents/OM-PRM/open-mercato
```

## Step 1: Always start here (Task Router)
```
$OM_REPO/AGENTS.md
```
Root AGENTS.md has the Task Router table — it tells you which guide to read for any given task.

## Step 2: Load 1-2 relevant module guides based on topic

| Investigating... | Read |
|-----------------|------|
| Module dev, CRUD, API routes, events, widgets, setup.ts | `$OM_REPO/packages/core/AGENTS.md` |
| UI components, forms, data tables, backend pages, portal | `$OM_REPO/packages/ui/AGENTS.md` |
| Backend page components, apiCall, RowActions | `$OM_REPO/packages/ui/src/backend/AGENTS.md` |
| CRM patterns — **reference module to copy** | `$OM_REPO/packages/core/src/modules/customers/AGENTS.md` |
| Auth, RBAC, roles, features, user management | `$OM_REPO/packages/core/src/modules/auth/AGENTS.md` |
| Customer accounts, portal auth, self-registration | `$OM_REPO/packages/core/src/modules/customer_accounts/AGENTS.md` |
| Workflows (step-based, timers, user tasks) | `$OM_REPO/packages/core/src/modules/workflows/AGENTS.md` |
| Sales (orders, quotes, invoices) | `$OM_REPO/packages/core/src/modules/sales/AGENTS.md` |
| Catalog (products, variants, pricing) | `$OM_REPO/packages/core/src/modules/catalog/AGENTS.md` |
| Integrations, data sync | `$OM_REPO/packages/core/src/modules/integrations/AGENTS.md` + `data_sync/AGENTS.md` |
| Search (fulltext, vector, tokens) | `$OM_REPO/packages/search/AGENTS.md` |
| Background jobs, workers | `$OM_REPO/packages/queue/AGENTS.md` |
| Caching | `$OM_REPO/packages/cache/AGENTS.md` |
| Events, event bus, DOM event bridge | `$OM_REPO/packages/events/AGENTS.md` |
| Shared utilities, types, DSL, i18n | `$OM_REPO/packages/shared/AGENTS.md` |
| CLI tooling, generators, migrations | `$OM_REPO/packages/cli/AGENTS.md` |
| Onboarding wizards, tenant setup | `$OM_REPO/packages/onboarding/AGENTS.md` |
| Enterprise overlay | `$OM_REPO/packages/enterprise/AGENTS.md` |
| Currencies, exchange rates | `$OM_REPO/packages/core/src/modules/currencies/AGENTS.md` |
| create-mercato-app template | `$OM_REPO/packages/create-app/AGENTS.md` + `template/AGENTS.md` |
| AI assistant, MCP tools | `$OM_REPO/packages/ai-assistant/AGENTS.md` |
| n8n automation, external orchestration | `open-mercato/n8n-nodes` repo (check via `gh` CLI) |
| Official marketplace modules | `open-mercato/official-modules` repo (check via `gh` CLI) |

## Step 3: Specs (when checking requirements or conflicts)
```
$OM_REPO/.ai/specs/                     — OSS specs
$OM_REPO/.ai/specs/enterprise/          — Enterprise specs (feature-toggled, never mixed into core)
$OM_REPO/.ai/specs/AGENTS.md            — Spec writing rules
```

## Step 4: Actual code (when verifying "does X exist?")
```
$OM_REPO/packages/core/src/modules/     — All core module source
$OM_REPO/packages/*/src/                — Package implementations
$OM_REPO/.github/workflows/             — CI pipelines
```

## Step 5: External OM repos (when checking ecosystem capabilities)

| Repo | What it is | When to check |
|------|-----------|---------------|
| `open-mercato/official-modules` | Marketplace modules as separate npm packages. Modules that ship outside core. | When investigating if a capability exists as an official module rather than in core. `gh repo view open-mercato/official-modules` or clone to check. |
| `open-mercato/n8n-nodes` | n8n community nodes for Open Mercato. Generic REST node that speaks OM API. | When investigating automation, external orchestration, or LLM integration patterns. n8n is the recommended automation + AI layer for apps that need scheduled/triggered external processing. |
| `open-mercato/open-mercato` `.ai/specs/enterprise/` | Enterprise overlay specs. Feature-toggled capabilities that extend core modules. | When checking if a "missing" feature is actually enterprise-only. Don't build in an app what enterprise already provides. |

## Loading rules for external repos
- Use `gh` CLI to browse without cloning: `gh api repos/open-mercato/<repo>/contents/<path>`
- Only clone if you need to search code. Keep external repos outside the OM_REPO path.
- Enterprise specs are in the main repo but gated — check them when a feature seems like it should exist but doesn't in OSS.

## Loading Rules

- **Max 2-3 AGENTS.md per investigation.** Root + the specific module. No more.
- **Always start with root AGENTS.md** — Task Router tells you where to look.
- **Use Grep/Glob for targeted searches** — don't read entire files when looking for a specific function.
- **Verify on upstream** — `git -C $OM_REPO fetch upstream` then search against upstream branches.
- **Don't load what you don't need** — "Agent will blow up context window."

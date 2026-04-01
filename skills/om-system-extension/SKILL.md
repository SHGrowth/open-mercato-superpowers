---
name: om-system-extension
description: Extend core Open Mercato modules using the Universal Module Extension System (UMES). Use when adding columns/fields/filters to existing tables/forms, enriching API responses, intercepting API routes, blocking/validating mutations, replacing UI components, injecting menu items, or reacting to domain events. Triggers on "extend", "add column to", "add field to", "inject into", "intercept", "enrich", "hook into", "customize", "override component", "add menu item", "react to event", "block mutation", "validate before save", "UMES".
---

# System Extension — UMES Wizard

Extend any core module without modifying its source code. Select the right UMES mechanism, generate files, wire correctly.

Templates: `references/extension-templates.md` | Type contracts: `references/extension-contracts.md`

## 1. Decision Tree

Match the developer's goal to the correct mechanism(s).

| Goal | Mechanism(s) Required | Section |
|------|----------------------|---------|
| **Add data to another module's API response** | Response Enricher | §2 |
| **Add a field to another module's form** | Response Enricher + Field Widget + injection-table (Triad) | §12 |
| **Add a column to another module's table** | Response Enricher + Column Widget + injection-table (Triad) | §12 |
| **Add a filter to another module's table** | Filter Widget + injection-table + API Interceptor (for server filters) | §5 + §8 |
| **Add row/bulk actions to another module's table** | Row Action / Bulk Action Widget + injection-table | §6 |
| **Add a menu item to sidebar/topbar** | Menu Item Widget + injection-table | §7 |
| **Validate/block a request before it reaches an API route** | API Interceptor (before hook) | §8 |
| **Transform/enrich an API response after it returns** | API Interceptor (after hook) or Response Enricher | §8 or §2 |
| **Block/validate mutations before entity persistence** | Mutation Guard | §9 |
| **Replace or wrap a UI component** | Component Replacement | §10 |
| **React to domain events (after entity create/update/delete)** | Event Subscriber | §11 |
| **Add a tab/section to a detail page** | Widget Injection (tab kind) + injection-table | §6 |

**Multiple mechanisms needed?** Follow the **Triad Pattern** (§12): enricher + widget + injection-table.

---

## 2. Response Enrichers

**Purpose**: Add computed fields to another module's API response, namespaced under `_<yourModule>`.

**File**: `data/enrichers.ts` — export `enrichers` array.

**Key rules:**
- MUST implement `enrichMany` (batch with `$in`) — no N+1
- MUST namespace under `_<yourModule>` — additive only, never modify existing fields
- Set `timeout` and `fallback` for resilience; `critical: false` (default) so failures don't break target API

Template + EnricherContext: `references/extension-templates.md` § Response Enrichers.

---

## 3. Widget Injection — Fields

**Purpose**: Add an editable field to another module's CrudForm.

**File**: `widgets/injection/<widget-name>/widget.ts` — export default `InjectionFieldWidget`.

**Key rules:**
- Field `id` MUST match enricher namespace path (e.g., `_example.priority`)
- `onSave` MUST be idempotent (upsert pattern: check-then-create-or-update)
- Widget `onSave` fires BEFORE the core form save — design for partial failure
- The field reads its initial value from the enriched API response automatically

Template: `references/extension-templates.md` § Widget Injection — Fields.

---

## 4. Widget Injection — Columns

**Purpose**: Add a column to another module's DataTable.

**File**: `widgets/injection/<widget-name>/widget.ts` — export default `InjectionColumnWidget`.

**Key rules:**
- `accessorKey` MUST point to enriched field path (e.g., `_example.priority`)
- `sortable` MUST be `false` for enriched-only fields (not in database index)
- Requires a matching Response Enricher that provides the data (Triad Pattern §12)

Template: `references/extension-templates.md` § Widget Injection — Columns.

---

## 5. Widget Injection — Filters

**Purpose**: Add a filter control to another module's DataTable filter bar.

**File**: `widgets/injection/<widget-name>/widget.ts` — export default `InjectionFilterWidget`.

**Key rules:**
- Server filters (`strategy: 'server'`) require a matching API Interceptor to handle the `queryParam`
- Prefer `ids` query narrowing over post-filtering response arrays
- Return `ids: 'NONE'` to return empty results when no matches found

Template + server-side interceptor: `references/extension-templates.md` § Widget Injection — Filters.

---

## 6. Widget Injection — Row Actions, Bulk Actions & Tabs

**Purpose**: Add context menu actions, bulk operations, or tabs to a DataTable/detail page.

**File**: `widgets/injection/<widget-name>/widget.ts`

**Key rules:**
- Use `InjectionPosition` for relative placement — never hardcode positions
- Always set `features` for ACL-gated actions
- Bulk action `onExecute` should call `refresh()` after mutation
- Tab widgets use a `widget.client.tsx` client component

Templates: `references/extension-templates.md` § Widget Injection — Row Actions & Bulk Actions.

---

## 7. Widget Injection — Menu Items

**Purpose**: Add items to sidebar, topbar, or profile dropdown.

**File**: `widgets/injection/<widget-name>/widget.ts` — export default `InjectionMenuItemWidget`.

**Key rules:**
- Use `labelKey` (i18n) instead of `label` whenever possible
- Always set `features` for permission-gated items
- Use `groupId` + `groupLabelKey` to group related menu items

Template + Spot IDs: `references/extension-templates.md` § Widget Injection — Menu Items.

---

## 8. API Interceptors

**Purpose**: Validate, transform, or enrich requests/responses on existing API routes.

**File**: `api/interceptors.ts` — export `interceptors` array.

**Key rules:**
- `before` hook: return `{ ok: false, message }` to reject — never throw errors
- `after` hook: use `merge` to add fields, `replace` to swap entire response body
- Prefer exact `targetRoute` over wildcards — wildcards match too broadly
- For filtering: rewrite `query.ids` (comma-separated UUIDs) — never post-filter response arrays

Template: `references/extension-templates.md` § API Interceptors.

---

## 9. Mutation Guards

**Purpose**: Block or validate entity mutations before DB persistence (after interceptors, before ORM flush).

**File**: `data/guards.ts` — export `guards` array.

**Key rules:**
- `resourceId` is `null` for create operations — handle this case
- Return a new object for `modifiedPayload` — never mutate `input.mutationPayload` in place
- Guards with `targetEntity: '*'` run on EVERY entity mutation — use sparingly
- Return structured `{ ok: false, message }` — never throw

Template: `references/extension-templates.md` § Mutation Guards.

---

## 10. Component Replacement

**Purpose**: Replace, wrap, or transform props of registered UI components.

**File**: `widgets/components.ts` — export `componentOverrides` array.

**Key rules:**
- Prefer `wrapper` mode — preserves original component, least likely to break
- `replacement` mode REQUIRES a `propsSchema` (Zod) for dev-mode contract validation
- Always set `displayName` on wrapper components for React DevTools debugging
- Wrapper composition: lower priority = innermost, higher priority = outermost

Templates (all 3 modes) + Handle IDs: `references/extension-templates.md` § Component Replacement.

---

## 11. Event Subscribers

**Purpose**: React to domain events (entity create/update/delete) from other modules.

**File**: `subscribers/<subscriber-name>.ts` — named export `metadata` + default export handler.

**Key rules:**
- After-events (`.created`, `.updated`, `.deleted`) are fire-and-forget — cannot block
- Before-events (`.creating`, `.updating`, `.deleting`) require `sync: true` to block mutations
- Subscribers MUST be idempotent — events may be delivered more than once
- Use `persistent: true` for critical side effects that must survive restarts

Templates + Event Naming Convention: `references/extension-templates.md` § Event Subscribers.

---

## 12. The Triad Pattern

When extending another module's UI with data from your module, you need three coordinated pieces:

```
ENRICHER (data/enrichers.ts)  ->  WIDGET (widgets/injection/<name>/widget.ts)  ->  INJECTION TABLE (widgets/injection-table.ts)
  Adds _<module> to API            Renders enriched data as field/column          Maps widget to target spot ID
```

**Flow**: Enricher adds `_<module>` data -> Widget renders it -> Injection table maps widget to spot ID -> `yarn generate`.

**Spot IDs**: `crud-form:<entityId>:fields`, `data-table:<tableId>:columns`, `data-table:<tableId>:row-actions`, `data-table:<tableId>:bulk-actions`, `data-table:<tableId>:filters`.

Full 3-step example: `references/extension-templates.md` § The Triad Pattern.

---

## 13. Wiring & Verification

### File Checklist

After implementing an extension, verify all files exist:

| File | Required When |
|------|--------------|
| `data/enrichers.ts` | Adding data to another module's API response |
| `widgets/injection/<name>/widget.ts` | Adding UI elements (fields, columns, actions, menus) |
| `widgets/injection-table.ts` | Mapping widgets to target spots |
| `widgets/components.ts` | Replacing/wrapping UI components |
| `api/interceptors.ts` | Intercepting API routes |
| `data/guards.ts` | Blocking/validating mutations |
| `subscribers/<name>.ts` | Reacting to domain events |

### Post-Implementation Steps

1. `yarn generate` — registers new enrichers, widgets, interceptors, guards
2. `yarn dev` — verify extension appears in target module UI
3. Check browser console for warnings about invalid spot IDs or missing enrichers
4. Test full flow — create/edit/delete in target module, verify extension works

### Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Missing `enrichMany` | Slow list pages, N+1 queries | Implement batch enrichment with `$in` query |
| Wrong spot ID | Widget doesn't appear | Check exact spot ID format in target module |
| Missing `yarn generate` | Extension not discovered | Run `yarn generate` after adding files |
| Hardcoded strings | i18n warnings | Use `labelKey` / i18n keys everywhere |
| Missing `features` | Extension visible to all users | Add ACL `features` array |
| `onSave` not idempotent | Duplicate records on retry | Use upsert pattern (check-then-create-or-update) |
| `sortable: true` on enriched column | Sort doesn't work | Set `sortable: false` for enriched-only fields |
| Throw in interceptor | 500 error | Return `{ ok: false, message }` instead |
| Missing injection-table entry | Widget exists but not rendered | Add mapping in `injection-table.ts` |

---

## Rules

Follow all conventions from the relevant module AGENTS.md (loaded via Task Router). The rules below are specific to UMES extensions:

- **MUST** run `yarn generate` after adding any extension file
- **MUST** implement `enrichMany` when creating Response Enrichers — no N+1
- **MUST** namespace enriched fields under `_<your-module>` prefix — additive only
- **MUST** make `onSave` endpoints idempotent (upsert pattern)
- **MUST** use `{ ok: false, message }` pattern instead of throwing errors in interceptors/guards
- **MUST** set `sortable: false` on columns backed by enriched data only
- **MUST NOT** use wildcard interceptor routes unless absolutely necessary
- Prefer Response Enrichers over API Interceptor `after` hooks for adding data to responses
- Prefer Mutation Guards over sync before-event subscribers for blocking mutations
- When extending UI and data together, always follow the Triad Pattern (enricher + widget + injection-table)

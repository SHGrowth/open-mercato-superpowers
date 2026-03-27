# Dashboard Widget Control for Apps

## Problem
OM seeds default dashboard widgets (Customer Todos, New Deals, New Quotes, etc.) for built-in roles during `onTenantCreated`. Apps that don't use those modules get irrelevant widgets cluttering the dashboard.

## How Dashboard Widgets Work (3 layers)

1. **Widget registration** — modules register widgets via auto-discovery (`widgets/dashboard/*/widget.ts`). Each has `metadata.defaultEnabled` and `metadata.features`.

2. **Role-level widget list** (`DashboardRoleWidgets` entity) — `seedDashboardDefaultsForTenant` seeds widget IDs per role. Admin/superadmin get ALL widgets. Employee gets `defaultEnabled: true` only.

3. **Access resolution** (`dashboards/lib/access.ts`) — at render time, `resolveAllowedWidgetIds` intersects role widget list + user overrides + feature checks. Widgets whose required features aren't granted to the role are filtered out.

## Two Control Mechanisms

### 1. Feature gating (custom roles — zero code)

Custom app roles (e.g., `partner_admin`, `consultant`) only get features declared in `defaultRoleFeatures`. If the role doesn't have `customers.widgets.todos` or `sales.*` features, those widgets are automatically hidden by the access layer.

**This works out of the box for any custom role.** No configuration needed.

### 2. Explicit widget replacement (built-in roles — `seedDefaults`)

For built-in roles (`admin`, `employee`) that inherit features from core modules (e.g., `customers.*`), use `seedDashboardDefaultsForTenant` with explicit `widgetIds` in your app's `seedDefaults`:

```typescript
import { seedDashboardDefaultsForTenant } from '@open-mercato/core/modules/dashboards/cli'

// In setup.ts seedDefaults:
await seedDashboardDefaultsForTenant(em, {
  tenantId,
  organizationId,
  roleNames: ['admin', 'employee'],
  widgetIds: [
    // Only your app's widgets — replaces the entire default set
    'myapp.dashboard.widget-a',
    'myapp.dashboard.widget-b',
  ],
  logger: () => {},
})
```

**How it works:** When a `DashboardRoleWidgets` record already exists for a role (seeded by `onTenantCreated`), `seedDashboardDefaultsForTenant` does a full replace of `widgetIdsJson` (cli.ts line 76). So calling it again with explicit IDs overwrites the default set.

**Timing:** Call this in `seedDefaults` (runs after `onTenantCreated`), so the default widgets are created first by the dashboards module, then replaced by your app.

## When to Use Which

| Scenario | Mechanism | Code needed |
|----------|-----------|-------------|
| Custom app roles (not admin/employee) | Feature gating | None — works automatically |
| Built-in admin/employee roles | `seedDashboardDefaultsForTenant` with explicit `widgetIds` | 10 lines in seedDefaults |
| Future enhancement (upstream) | `removeWidgetsFromRoles` — selective removal instead of full replace | ~20 lines upstream PR (not yet available) |

## Anti-pattern

Don't leave default OM widgets active for roles that don't need them. Dashboard clutter confuses users and makes the app look unfinished. Control widgets via feature gating (custom roles) or explicit replacement (built-in roles).

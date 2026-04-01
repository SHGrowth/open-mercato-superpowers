# Extension Templates

Code templates for each UMES extension mechanism. Referenced by om-system-extension.

---

## Response Enrichers

### Template

```typescript
import type { ResponseEnricher, EnricherContext } from '@open-mercato/shared/lib/crud/response-enricher'

const enricher: ResponseEnricher = {
  id: '<your-module>.<enricher-name>',
  targetEntity: '<target-module>.<entity>',  // e.g., 'customers.person'
  priority: 50,
  timeout: 2000,
  fallback: { _<your-module>: {} },

  async enrichOne(record, context: EnricherContext) {
    const em = context.em as EntityManager
    // Fetch your data for this single record
    const data = await em.findOne(YourEntity, {
      foreignId: record.id,
      organizationId: context.organizationId,
    })
    return {
      ...record,
      _<your-module>: {
        fieldName: data?.value ?? null,
      },
    }
  },

  // REQUIRED for list endpoints — prevents N+1 queries
  async enrichMany(records, context: EnricherContext) {
    const em = context.em as EntityManager
    const ids = records.map(r => r.id)
    // Single batch query for ALL records
    const items = await em.find(YourEntity, {
      foreignId: { $in: ids },
      organizationId: context.organizationId,
    })
    const byForeignId = new Map(items.map(i => [i.foreignId, i]))
    return records.map(r => ({
      ...r,
      _<your-module>: {
        fieldName: byForeignId.get(r.id)?.value ?? null,
      },
    }))
  },
}

export const enrichers = [enricher]
```

### EnricherContext Interface

```typescript
interface EnricherContext {
  organizationId: string    // Current tenant org
  tenantId: string          // Current tenant
  userId: string            // Authenticated user
  em: EntityManager         // Read-only database access
  container: AwilixContainer // DI container
  requestedFields?: string[] // Sparse fieldset request
  userFeatures?: string[]   // User's ACL features
}
```

---

## Widget Injection — Fields

### InjectionFieldWidget Template

```typescript
import type { InjectionFieldWidget } from '@open-mercato/shared/modules/widgets'
import { readApiResultOrThrow } from '@open-mercato/ui/backend/utils/apiCall'

const widget: InjectionFieldWidget = {
  metadata: { id: '<your-module>.injection.<field-name>', priority: 50 },
  fields: [
    {
      id: '_<your-module>.<fieldName>',  // Matches enricher namespace
      label: '<your-module>.fields.<fieldName>',  // i18n key
      type: 'select',  // text | textarea | number | select | checkbox | date | custom
      group: 'details',  // Target group in CrudForm
      options: [
        { value: 'option1', label: '<your-module>.options.option1' },
        { value: 'option2', label: '<your-module>.options.option2' },
      ],
    },
  ],
  eventHandlers: {
    onSave: async (data, context) => {
      const resourceId = (context as Record<string, unknown>).resourceId as string
      const value = (data as Record<string, unknown>)['_<your-module>.<fieldName>']

      // Upsert pattern — idempotent save
      const existing = await readApiResultOrThrow<{ items: Array<{ id: string }> }>(
        `/api/<your-module>/resource?foreignId=${resourceId}`,
      )
      if (existing?.items?.[0]?.id) {
        await readApiResultOrThrow(`/api/<your-module>/resource`, {
          method: 'PUT',
          body: JSON.stringify({ id: existing.items[0].id, foreignId: resourceId, value }),
        })
      } else {
        await readApiResultOrThrow(`/api/<your-module>/resource`, {
          method: 'POST',
          body: JSON.stringify({ foreignId: resourceId, value }),
        })
      }
    },
  },
}

export default widget
```

---

## Widget Injection — Columns

### InjectionColumnWidget Template

```typescript
import type { InjectionColumnWidget } from '@open-mercato/shared/modules/widgets'

const widget: InjectionColumnWidget = {
  metadata: { id: '<your-module>.injection.<column-name>', priority: 40 },
  columns: [
    {
      id: '<your-module>_<fieldName>',
      header: '<your-module>.columns.<fieldName>',  // i18n key
      accessorKey: '_<your-module>.<fieldName>',     // Path to enriched data
      sortable: false,  // MUST be false for enriched-only fields
      cell: ({ getValue }) => {
        const value = getValue()
        return typeof value === 'string' ? value : '—'
      },
    },
  ],
}

export default widget
```

---

## Widget Injection — Filters

### InjectionFilterWidget Template

```typescript
import type { InjectionFilterWidget } from '@open-mercato/shared/modules/widgets'

const widget: InjectionFilterWidget = {
  metadata: { id: '<your-module>.injection.<filter-name>', priority: 35 },
  filters: [
    {
      id: '<your-module><FilterName>',
      label: '<your-module>.filters.<filterName>',  // i18n key
      type: 'select',  // select | text | date | dateRange | boolean
      strategy: 'server',  // 'server' = sent as query param, 'client' = filtered locally
      queryParam: '<your-module><FilterName>',
      options: [
        { value: 'value1', label: '<your-module>.options.value1' },
        { value: 'value2', label: '<your-module>.options.value2' },
      ],
    },
  ],
}

export default widget
```

### Server-Side Filter Interceptor

When `strategy: 'server'`, pair with this API Interceptor:

```typescript
// api/interceptors.ts
const filterInterceptor: ApiInterceptor = {
  id: '<your-module>.filter-by-<filterName>',
  targetRoute: '<target-module>/<entities>',  // e.g., 'customers/people'
  methods: ['GET'],
  priority: 50,
  async before(request, context) {
    const filterValue = request.query?.['<your-module><FilterName>']
    if (!filterValue) return { ok: true }

    // Query your data to find matching target IDs
    const em = context.em as EntityManager
    const matches = await em.find(YourEntity, {
      fieldName: filterValue,
      organizationId: context.organizationId,
    })
    const matchingIds = matches.map(m => m.foreignId)

    if (matchingIds.length === 0) {
      return { ok: true, query: { ...request.query, ids: 'NONE' } }
    }

    // Narrow results by rewriting the ids query parameter
    const existingIds = request.query?.ids as string | undefined
    const narrowedIds = existingIds
      ? matchingIds.filter(id => existingIds.split(',').includes(id))
      : matchingIds
    return { ok: true, query: { ...request.query, ids: narrowedIds.join(',') } }
  },
}
```

---

## Widget Injection — Row Actions & Bulk Actions

### Row Action Template

```typescript
import type { InjectionRowActionWidget } from '@open-mercato/shared/modules/widgets'
import { InjectionPosition } from '@open-mercato/shared/modules/widgets/injection-position'

const widget: InjectionRowActionWidget = {
  metadata: { id: '<your-module>.injection.<action-name>', priority: 30 },
  rowActions: [
    {
      id: '<your-module>.<entity>.<action>',
      label: '<your-module>.actions.<actionName>',  // i18n key
      icon: 'CheckSquare',  // Lucide icon name
      features: ['<your-module>.<action>'],  // ACL gating
      placement: { position: InjectionPosition.After, relativeTo: 'edit' },
      onSelect: (row, context) => {
        const id = (row as Record<string, unknown>).id as string
        const navigate = (context as { navigate?: (path: string) => void }).navigate
        navigate?.(`/backend/<your-module>/resource/${id}`)
      },
    },
  ],
}

export default widget
```

### Bulk Action Template

```typescript
import type { InjectionBulkActionWidget } from '@open-mercato/shared/modules/widgets'

const widget: InjectionBulkActionWidget = {
  metadata: { id: '<your-module>.injection.bulk-<action-name>', priority: 30 },
  bulkActions: [
    {
      id: '<your-module>.bulk.<action>',
      label: '<your-module>.actions.bulk<ActionName>',
      features: ['<your-module>.<action>'],
      onExecute: async (selectedRows, context) => {
        const ids = selectedRows.map(r => (r as Record<string, unknown>).id)
        await readApiResultOrThrow(`/api/<your-module>/bulk-action`, {
          method: 'POST',
          body: JSON.stringify({ targetIds: ids }),
        })
        ;(context as { refresh?: () => void }).refresh?.()
      },
    },
  ],
}

export default widget
```

### Tab Widget Template (Detail Pages)

```typescript
import type { InjectionWidget } from '@open-mercato/shared/modules/widgets'

const widget: InjectionWidget = {
  metadata: { id: '<your-module>.injection.<tab-name>', priority: 40 },
  component: () => import('./widget.client'),
}

export default widget
```

Client component at `widget.client.tsx`:

```tsx
'use client'
import { useT } from '@open-mercato/shared/lib/i18n/context'

export default function MyTabContent({ context }: { context: Record<string, unknown> }) {
  const t = useT()
  const resourceId = context.resourceId as string
  // Fetch and display your data
  return <div>...</div>
}
```

---

## Widget Injection — Menu Items

### InjectionMenuItemWidget Template

```typescript
import type { InjectionMenuItemWidget } from '@open-mercato/shared/modules/widgets'
import { InjectionPosition } from '@open-mercato/shared/modules/widgets/injection-position'

const widget: InjectionMenuItemWidget = {
  metadata: { id: '<your-module>.injection.menus' },
  menuItems: [
    {
      id: '<your-module>-<page>-link',
      labelKey: '<your-module>.menu.<pageName>',  // i18n key
      label: 'Fallback Label',  // Fallback if i18n missing
      icon: 'LayoutDashboard',  // Lucide icon name
      href: '/backend/<your-module>',
      features: ['<your-module>.view'],  // ACL gating
      groupId: '<your-module>.nav.group',
      groupLabelKey: '<your-module>.nav.group',
      placement: { position: InjectionPosition.Last },
    },
  ],
}

export default widget
```

### Available Spot IDs

| Spot ID | Location |
|---------|----------|
| `menu:sidebar:main` | Main sidebar navigation |
| `menu:sidebar:settings` | Settings sidebar |
| `menu:sidebar:profile` | Profile sidebar |
| `menu:topbar:profile-dropdown` | User profile dropdown |
| `menu:topbar:actions` | Top bar action area |

---

## API Interceptors

### ApiInterceptor Template

```typescript
import type { ApiInterceptor } from '@open-mercato/shared/lib/crud/api-interceptor'

const interceptors: ApiInterceptor[] = [
  {
    id: '<your-module>.validate-<action>',
    targetRoute: '<target-module>/<entities>',  // e.g., 'customers/people'
    methods: ['POST', 'PUT'],
    priority: 50,  // Lower = earlier execution
    timeoutMs: 5000,

    async before(request, context) {
      // Validate request
      const value = request.body?.someField
      if (!value) {
        return { ok: false, statusCode: 422, message: 'someField is required' }
      }
      // Optionally rewrite body or query
      return { ok: true, body: { ...request.body, normalizedField: String(value).trim() } }
    },

    async after(request, response, context) {
      // Optionally enrich response
      return {
        merge: {
          _<your-module>: { processedAt: Date.now() },
        },
      }
    },
  },
]

export { interceptors }
```

---

## Mutation Guards

### MutationGuard Template

```typescript
import type { MutationGuard, MutationGuardInput, MutationGuardResult } from '@open-mercato/shared/lib/crud/mutation-guard-registry'

const guard: MutationGuard = {
  id: '<your-module>.<guard-name>',
  targetEntity: '<target-module>.<entity>',  // or '*' for all entities
  operations: ['create', 'update'],  // create | update | delete
  priority: 50,  // Lower = earlier execution

  async validate(input: MutationGuardInput): Promise<MutationGuardResult> {
    // input.resourceId is null for create operations
    // input.mutationPayload contains the data being saved

    if (someConditionFails) {
      return {
        ok: false,
        status: 422,
        message: 'Validation failed: reason',
      }
    }

    // Optionally transform payload
    return {
      ok: true,
      modifiedPayload: { ...input.mutationPayload, normalizedField: 'value' },
      shouldRunAfterSuccess: true,
      metadata: { originalValue: input.mutationPayload?.field },
    }
  },

  async afterSuccess(input) {
    // Runs after successful mutation — for cleanup, cache invalidation, logging
    // input.metadata contains what you passed from validate()
  },
}

export const guards = [guard]
```

---

## Component Replacement

### Template — All Three Modes

```typescript
import React from 'react'
import type { ComponentOverride } from '@open-mercato/shared/modules/widgets/component-registry'
import { ComponentReplacementHandles } from '@open-mercato/shared/modules/widgets/component-registry'

export const componentOverrides: ComponentOverride[] = [
  // Mode 1: Wrapper — decorate existing component (safest)
  {
    target: { componentId: ComponentReplacementHandles.section('ui.detail', 'NotesSection') },
    priority: 50,
    metadata: { module: '<your-module>' },
    wrapper: (Original) => {
      const Wrapped = (props: any) =>
        React.createElement(
          'div',
          { className: 'border border-blue-200 rounded-md p-2' },
          React.createElement(Original, props),
        )
      Wrapped.displayName = '<YourModule>NotesWrapper'
      return Wrapped
    },
  },

  // Mode 2: Props transform — modify incoming props
  {
    target: { componentId: ComponentReplacementHandles.dataTable('customers.people') },
    priority: 40,
    metadata: { module: '<your-module>' },
    propsTransform: (props: any) => ({
      ...props,
      defaultPageSize: 25,
    }),
  },

  // Mode 3: Replace — full component swap (highest risk)
  {
    target: { componentId: ComponentReplacementHandles.section('sales.order', 'ShipmentDialog') },
    priority: 50,
    metadata: { module: '<your-module>' },
    replacement: React.lazy(() => import('./CustomShipmentDialog')),
    propsSchema: ShipmentDialogPropsSchema,  // Zod schema for validation
  },
]
```

### Handle IDs

| Handle | Format | Example |
|--------|--------|---------|
| `page` | `page:<path>` | `page:backend/customers/people` |
| `dataTable` | `data-table:<tableId>` | `data-table:customers.people` |
| `crudForm` | `crud-form:<entityId>` | `crud-form:customers.person` |
| `section` | `section:<scope>.<sectionId>` | `section:ui.detail.NotesSection` |

---

## Event Subscribers

### Async Subscriber Template (After-Event)

```typescript
export const metadata = {
  event: 'customers.person.created',  // module.entity.action (past tense)
  persistent: true,  // true = survives server restart (uses queue)
  id: '<your-module>:on-customer-created',
}

export default async function handler(payload: Record<string, unknown>, ctx: unknown) {
  const { resourceId, organizationId, tenantId } = payload as {
    resourceId: string
    organizationId: string
    tenantId: string
  }

  // Perform side effects
  // Examples: create related records, send notifications, sync external systems
}
```

### Sync Subscriber Template (Before-Event)

```typescript
export const metadata = {
  event: 'customers.person.creating',  // .creating = before event (present tense)
  persistent: false,
  id: '<your-module>:validate-customer-create',
  sync: true,      // Run synchronously in request pipeline
  priority: 50,    // Lower = earlier
}

export default async function handler(payload: Record<string, unknown>) {
  const data = payload as { mutationPayload?: Record<string, unknown> }

  if (someConditionFails(data.mutationPayload)) {
    return { ok: false, status: 422, message: 'Cannot create: reason' }
  }

  // Optionally modify the mutation data
  return { ok: true, modifiedPayload: { ...data.mutationPayload, enrichedField: 'value' } }
}
```

### Event Naming Convention

| Event | Timing | Can Block? |
|-------|--------|-----------|
| `module.entity.creating` | Before create | Yes (sync only) |
| `module.entity.created` | After create | No |
| `module.entity.updating` | Before update | Yes (sync only) |
| `module.entity.updated` | After update | No |
| `module.entity.deleting` | Before delete | Yes (sync only) |
| `module.entity.deleted` | After delete | No |

---

## The Triad Pattern — Example Code

### Example: Add "Priority" field to Customers form

**Step 1 — Enricher** (`data/enrichers.ts`):
```typescript
const enricher: ResponseEnricher = {
  id: 'priorities.customer-priority',
  targetEntity: 'customers.person',
  priority: 50,
  async enrichOne(record, context) {
    const priority = await em.findOne(CustomerPriority, { customerId: record.id })
    return { ...record, _priorities: { level: priority?.level ?? 'normal' } }
  },
  async enrichMany(records, context) {
    const items = await em.find(CustomerPriority, { customerId: { $in: records.map(r => r.id) } })
    const byId = new Map(items.map(i => [i.customerId, i.level]))
    return records.map(r => ({ ...r, _priorities: { level: byId.get(r.id) ?? 'normal' } }))
  },
}
export const enrichers = [enricher]
```

**Step 2 — Field Widget** (`widgets/injection/customer-priority-field/widget.ts`):
```typescript
const widget: InjectionFieldWidget = {
  metadata: { id: 'priorities.injection.customer-priority-field', priority: 50 },
  fields: [{
    id: '_priorities.level',
    label: 'priorities.fields.level',
    type: 'select',
    group: 'details',
    options: [
      { value: 'low', label: 'priorities.options.low' },
      { value: 'normal', label: 'priorities.options.normal' },
      { value: 'high', label: 'priorities.options.high' },
    ],
  }],
  eventHandlers: {
    onSave: async (data, context) => {
      const customerId = (context as any).resourceId
      const level = (data as any)['_priorities.level']
      await readApiResultOrThrow('/api/priorities/customer-priorities', {
        method: 'POST',
        body: JSON.stringify({ customerId, level }),
      })
    },
  },
}
export default widget
```

**Step 3 — Injection Table** (`widgets/injection-table.ts`):
```typescript
export const widgetInjections = {
  'crud-form:customers.person:fields': {
    widgetId: 'priorities.injection.customer-priority-field',
    priority: 50,
  },
}
```

**Step 4 — Run `yarn generate`** to wire everything up.

### Triad Spot ID Patterns

| Spot ID Pattern | Widget Type |
|----------------|-------------|
| `crud-form:<entityId>:fields` | `InjectionFieldWidget` |
| `data-table:<tableId>:columns` | `InjectionColumnWidget` |
| `data-table:<tableId>:row-actions` | `InjectionRowActionWidget` |
| `data-table:<tableId>:bulk-actions` | `InjectionBulkActionWidget` |
| `data-table:<tableId>:filters` | `InjectionFilterWidget` |

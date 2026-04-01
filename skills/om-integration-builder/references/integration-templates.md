# Integration Templates

Code templates for building integration provider packages. Referenced by om-integration-builder.

---

## Scaffold Package

### package.json

```json
{
  "name": "@open-mercato/<prefix><provider>",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": {
    ".": "./src/index.ts",
    "./*": "./src/*.ts",
    "./**/*": "./src/**/*.ts",
    "./**/**/*": "./src/**/**/*.ts",
    "./**/**/**/*": "./src/**/**/**/*.ts",
    "./**/**/**/**/*": "./src/**/**/**/**/*.ts"
  },
  "scripts": {
    "build": "tsc --project tsconfig.json",
    "test": "vitest run"
  },
  "dependencies": {
    "@open-mercato/shared": "workspace:*"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vitest": "^2.0.0"
  }
}
```

Add the external SDK as a dependency (e.g., `"stripe": "^17.0.0"`, `"@aws-sdk/client-s3": "^3.x"`).

### tsconfig.json

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

### src/index.ts

```typescript
export * from './modules/<module_id>/index'
```

---

## Core Files

### integration.ts (CRITICAL -- marketplace registration)

This is the most important file. It registers the integration into the marketplace.

```typescript
import type { IntegrationDefinition } from '@open-mercato/shared/modules/integrations'

export const integration: IntegrationDefinition = {
  id: '<module_id>',                          // e.g., 'gateway_stripe'
  title: '<Provider Display Name>',           // e.g., 'Stripe'
  description: '<one-line description>',
  category: '<category>',                     // payment | shipping | data_sync | communication | webhook | storage
  hub: '<hub_module>',                        // payment_gateways | shipping_carriers | data_sync | ...
  providerKey: '<provider_key>',              // e.g., 'stripe', 'dhl', 'sendgrid'
  icon: '<icon_id>',                          // icon identifier for UI
  package: '@open-mercato/<package-name>',
  version: '1.0.0',
  tags: ['<tag1>', '<tag2>'],
  credentials: {
    fields: [
      // Define ALL credentials needed to connect to the external service
      { key: 'apiKey', label: 'API Key', type: 'secret', required: true },
      { key: 'webhookSecret', label: 'Webhook Secret', type: 'secret', required: true,
        helpDetails: {
          kind: 'webhook_setup',
          title: 'Webhook Configuration',
          summary: 'Configure webhooks in the provider dashboard.',
          endpointPath: '/api/<hub>/webhook/<providerKey>',
          dashboardPathLabel: 'Provider Dashboard > Webhooks',
          steps: ['Go to provider dashboard', 'Add webhook URL', 'Copy signing secret'],
        }
      },
    ],
  },
  // Optional: versioned API adapters
  apiVersions: [
    { id: '2025-01-01', label: 'v2025-01-01 (latest)', status: 'stable', default: true },
  ],
  healthCheck: { service: '<providerKey>HealthCheck' },
}
```

**Credential field types**: `text`, `secret`, `url`, `select`, `boolean`, `oauth`, `ssh_keypair`

**Conditional visibility**: Use `visibleWhen` to show/hide fields based on other field values:
```typescript
{ key: 'endpoint', label: 'Custom Endpoint', type: 'url',
  visibleWhen: { field: 'useCustomEndpoint', equals: true } }
```

### Bundle Integration

For multi-integration providers (one npm package -> many integrations sharing credentials):

```typescript
import type { IntegrationBundle, IntegrationDefinition } from '@open-mercato/shared/modules/integrations'

export const bundle: IntegrationBundle = {
  id: 'sync_medusa',
  title: 'MedusaJS',
  description: 'Sync products, customers, and orders with MedusaJS',
  credentials: { fields: [
    { key: 'apiUrl', label: 'MedusaJS API URL', type: 'url', required: true },
    { key: 'apiKey', label: 'API Key', type: 'secret', required: true },
  ]},
  healthCheck: { service: 'medusaHealthCheck' },
}

export const integrations: IntegrationDefinition[] = [
  { id: 'sync_medusa_products', title: 'MedusaJS Products', category: 'data_sync', hub: 'data_sync', providerKey: 'medusa_products', bundleId: 'sync_medusa' },
  { id: 'sync_medusa_customers', title: 'MedusaJS Customers', category: 'data_sync', hub: 'data_sync', providerKey: 'medusa_customers', bundleId: 'sync_medusa' },
  { id: 'sync_medusa_orders', title: 'MedusaJS Orders', category: 'data_sync', hub: 'data_sync', providerKey: 'medusa_orders', bundleId: 'sync_medusa' },
]
```

### index.ts (module metadata)

```typescript
import type { ModuleInfo } from '@open-mercato/shared/modules/registry'
export const metadata: ModuleInfo = {
  name: '<module_id>',
  title: '<Provider> Integration',
  version: '0.1.0',
  description: '<what this integration does>',
  author: 'Open Mercato Team',
  license: 'Proprietary',
  ejectable: true,
}
export { features } from './acl'
```

### acl.ts

```typescript
export const features = [
  { id: '<module_id>.view', title: 'View <Provider> configuration', module: '<module_id>' },
  { id: '<module_id>.configure', title: 'Configure <Provider> settings', module: '<module_id>' },
]
```

### setup.ts

```typescript
import type { ModuleSetupConfig } from '@open-mercato/shared/modules/setup'

export const setup: ModuleSetupConfig = {
  defaultRoleFeatures: {
    superadmin: ['<module_id>.view', '<module_id>.configure'],
    admin: ['<module_id>.view', '<module_id>.configure'],
  },
}
export default setup
```

### setup.ts with Env Preconfiguration (REQUIRED PATTERN)

New integrations MUST support provider-owned env preconfiguration when credentials, mappings, channels, locales, or enabled state are likely to be managed by deployment automation.

Implementation rules:

1. Add a provider-local helper such as `lib/preset.ts` that reads env vars and builds the persisted provider settings.
2. Apply the preset from `setup.ts` so a fresh tenant can come up already configured when env vars are present.
3. Add a provider-local CLI command (for example `configure-from-env`) so operators can rerun the same logic later without touching core.
4. Persist through the normal services for that hub (credentials service, mapping APIs, state service, etc.).
5. Name env vars with the primary pattern `OM_INTEGRATION_<PROVIDER>_*` (for example `OM_INTEGRATION_AKENEO_API_URL`, `OM_INTEGRATION_STRIPE_SECRET_KEY`).
6. Legacy aliases may be accepted for backward compatibility, but docs and examples must show `OM_INTEGRATION_<PROVIDER>_*` as the canonical names.
7. Document the env vars in public docs or package docs using those canonical names.

Do not add provider-specific bootstrap logic to `packages/core/`.

```typescript
import type { ModuleSetupConfig } from '@open-mercato/shared/modules/setup'
import { createCredentialsService } from '@open-mercato/core/modules/integrations/lib/credentials-service'
import { createIntegrationStateService } from '@open-mercato/core/modules/integrations/lib/state-service'
import { applyMyProviderEnvPreset } from './lib/preset'

export const setup: ModuleSetupConfig = {
  defaultRoleFeatures: {
    superadmin: ['<module_id>.view', '<module_id>.configure'],
    admin: ['<module_id>.view', '<module_id>.configure'],
  },

  async onTenantCreated({ em, tenantId, organizationId }) {
    await applyMyProviderEnvPreset({
      credentialsService: createCredentialsService(em),
      stateService: createIntegrationStateService(em),
      scope: { tenantId, organizationId },
    })
  },
}

export default setup
```

### di.ts

```typescript
import type { AppContainer } from '@open-mercato/shared/lib/di/container'

export function register(container: AppContainer): void {
  // Register adapter(s) -- see Adapter section
  // Register health check -- see Health Check section
  // Register webhook handler -- see Webhook Processing section
}
```

---

## Adapters

Read `references/adapter-contracts.md` for the full type definitions per category.

### Payment Gateway (`GatewayAdapter`)

```typescript
// lib/adapters/v<version>.ts
import type { GatewayAdapter, CreateSessionInput, CreateSessionResult, ... } from '@open-mercato/shared/modules/payment_gateways/types'
import { createClient } from '../client'

export class MyGatewayAdapter implements GatewayAdapter {
  readonly providerKey = '<provider>'

  async createSession(input: CreateSessionInput): Promise<CreateSessionResult> { ... }
  async capture(input: CaptureInput): Promise<CaptureResult> { ... }
  async refund(input: RefundInput): Promise<RefundResult> { ... }
  async cancel(input: CancelInput): Promise<CancelResult> { ... }
  async getStatus(input: GetStatusInput): Promise<GatewayPaymentStatus> { ... }
  async verifyWebhook(input: VerifyWebhookInput): Promise<WebhookEvent> { ... }
  mapStatus(providerStatus: string, eventType?: string): UnifiedPaymentStatus { ... }
}
```

**DI registration** (in `di.ts`):
```typescript
import { registerGatewayAdapter, registerWebhookHandler } from '@open-mercato/shared/modules/payment_gateways/types'
import { MyGatewayAdapter } from './lib/adapters/v2025'

export function register(container: AppContainer): void {
  const adapter = new MyGatewayAdapter()
  registerGatewayAdapter(adapter, { version: '2025-01-01' })
  registerWebhookHandler('<provider>', (input) => adapter.verifyWebhook(input), { queue: '<provider>-webhook' })
}
```

### Shipping Carrier (`ShippingAdapter`)

```typescript
// lib/adapters/v<version>.ts
import type { ShippingAdapter } from '<path>/shipping_carriers/lib/adapter'

export class MyShippingAdapter implements ShippingAdapter {
  readonly providerKey = '<provider>'

  async calculateRates(input): Promise<ShippingRate[]> { ... }
  async createShipment(input): Promise<CreateShipmentResult> { ... }
  async getTracking(input): Promise<TrackingResult> { ... }
  async cancelShipment(input): Promise<{ status: UnifiedShipmentStatus }> { ... }
  async verifyWebhook(input): Promise<ShippingWebhookEvent> { ... }
  mapStatus(carrierStatus: string): UnifiedShipmentStatus { ... }
}
```

### Data Sync (`DataSyncAdapter`)

```typescript
// lib/adapters/v<version>.ts
import type { DataSyncAdapter, StreamImportInput, ImportBatch } from '<path>/data_sync/lib/adapter'

export class MySyncAdapter implements DataSyncAdapter {
  readonly providerKey = '<provider>'
  readonly direction = 'import' // or 'export' | 'bidirectional'
  readonly supportedEntities = ['products', 'customers']

  async *streamImport(input: StreamImportInput): AsyncIterable<ImportBatch> {
    let cursor = input.cursor
    let hasMore = true
    let batchIndex = 0
    while (hasMore) {
      const page = await this.fetchPage(input.entityType, cursor, input.credentials)
      yield { items: page.items, cursor: page.nextCursor, hasMore: page.hasMore, batchIndex }
      cursor = page.nextCursor
      hasMore = page.hasMore
      batchIndex++
    }
  }

  async getMapping(input): Promise<DataMapping> { ... }
  async validateConnection(input): Promise<ValidationResult> { ... }
}
```

### Status Mapping

Every adapter MUST implement bidirectional status mapping:

```typescript
// lib/status-map.ts

const STATUS_MAP: Record<string, UnifiedPaymentStatus> = {
  'provider_pending': 'pending',
  'provider_paid': 'captured',
  'provider_refunded': 'refunded',
  // ... map ALL provider statuses
}

export function mapProviderStatus(providerStatus: string): UnifiedPaymentStatus {
  return STATUS_MAP[providerStatus] ?? 'unknown'
}
```

### Client Factory

```typescript
// lib/client.ts

export function createClient(credentials: Record<string, unknown>) {
  const apiKey = credentials.secretKey as string
  if (!apiKey) throw new Error('Missing secretKey credential')
  return new ProviderSDK(apiKey)
}
```

**MUST**: Never store credentials -- resolve them fresh from `credentials` parameter on every call.

---

## Webhook Processing

### Webhook Handler

```typescript
// lib/webhook-handler.ts

export async function verifyProviderWebhook(input: VerifyWebhookInput): Promise<WebhookEvent> {
  const { rawBody, headers, credentials } = input
  const secret = credentials.webhookSecret as string
  // Use provider SDK for signature verification when available
  // Return normalized WebhookEvent
  return {
    eventType: '<provider>.<entity>.<action>',
    eventId: '<provider-event-id>',
    data: parsedPayload,
    idempotencyKey: `<provider>:${eventId}`,
    timestamp: new Date(parsedPayload.created),
  }
}
```

### Webhook Worker

```typescript
// workers/webhook-processor.ts

export const metadata = {
  queue: '<provider>-webhook',
  id: '<module_id>:webhook-processor',
  concurrency: 5,  // I/O-bound
}

export default async function handle(job: QueuedJob, ctx: JobContext) {
  // 1. Parse webhook event
  // 2. Resolve credentials via integrationCredentials service
  // 3. Process event (update local state, emit events)
  // 4. Log result via integrationLog service
}
```

### Webhook Guide (for admin UI)

```typescript
// webhook-guide.ts

import type { IntegrationCredentialWebhookHelp } from '@open-mercato/shared/modules/integrations'

export const webhookSetupGuide: IntegrationCredentialWebhookHelp = {
  kind: 'webhook_setup',
  title: '<Provider> Webhook Configuration',
  summary: 'Configure <Provider> to send webhook events to Open Mercato.',
  endpointPath: '/api/<hub>/webhook/<providerKey>',
  dashboardPathLabel: '<Provider> Dashboard > Developers > Webhooks',
  steps: [
    'Log in to your <Provider> dashboard',
    'Navigate to Developers > Webhooks',
    'Click "Add endpoint"',
    'Paste the webhook URL shown below',
    'Select the events you want to receive',
    'Copy the signing secret and paste it above',
  ],
  events: ['payment_intent.succeeded', 'charge.refunded'],
  localDevelopment: {
    tunnelCommand: 'npx localtunnel --port 3000',
    publicUrlExample: 'https://xxx.loca.lt/api/<hub>/webhook/<providerKey>',
    note: 'Use a tunnel for local webhook testing',
  },
}
```

---

## Health Check

```typescript
// lib/health.ts

import type { AppContainer } from '@open-mercato/shared/lib/di/container'

export function createHealthCheck(container: AppContainer) {
  return {
    async check(credentials: Record<string, unknown>): Promise<{
      healthy: boolean
      details?: Record<string, unknown>
      message?: string
    }> {
      try {
        const client = createClient(credentials)
        const result = await client.someValidationEndpoint()
        return { healthy: true, details: { accountId: result.id } }
      } catch (error) {
        return {
          healthy: false,
          message: error instanceof Error ? error.message : 'Connection failed',
        }
      }
    },
  }
}
```

**DI registration** (add to `di.ts`):
```typescript
import { asFunction } from 'awilix'
container.register({
  '<providerKey>HealthCheck': asFunction(createHealthCheck).singleton(),
})
```

The `service` name MUST match `integration.ts` -> `healthCheck.service`.

---

## Widget Injection

### Widget Metadata

```typescript
// widgets/injection/<widget-name>/widget.ts

import type { WidgetDefinition } from '@open-mercato/shared/modules/widgets'

export const widget: WidgetDefinition = {
  id: '<module_id>:config',
  type: 'injection',
  label: '<Provider> Configuration',
  component: () => import('./widget.client'),
}
```

### Widget Component

```typescript
// widgets/injection/<widget-name>/widget.client.tsx
'use client'

import { useT } from '@open-mercato/shared/lib/i18n/context'

export default function ProviderConfigWidget({ context }: { context: Record<string, unknown> }) {
  const t = useT()
  // Render provider-specific configuration UI
  // context contains: integrationId, credentials (masked), isEnabled, scope
  return <div>...</div>
}
```

### Injection Table

```typescript
// widgets/injection-table.ts

export const widgetInjections = [
  {
    widgetId: '<module_id>:config',
    spotId: 'integrations.detail:tabs',
    position: 'append',
    metadata: { tab: { label: 'Configuration', icon: 'settings' } },
  },
]
```

**Available injection spots for integrations**:
- `integrations.detail:tabs` -- tab on integration detail page
- `integrations.detail:settings` -- settings section
- `integrations.bundle:tabs` -- tab on bundle detail page

---

## i18n

### English Translations

```typescript
// i18n/en.ts

export default {
  '<module_id>': {
    title: '<Provider>',
    description: '<one-line description>',
    credentials: {
      apiKey: 'API Key',
      webhookSecret: 'Webhook Signing Secret',
    },
    status: {
      connected: 'Connected',
      disconnected: 'Disconnected',
    },
    errors: {
      invalidCredentials: 'Invalid credentials',
      connectionFailed: 'Connection to <Provider> failed',
    },
  },
}
```

---

## Tests

### Unit Test

```typescript
// __tests__/status-map.test.ts

import { describe, it, expect } from 'vitest'
import { mapProviderStatus } from '../lib/status-map'

describe('status-map', () => {
  it('maps known statuses', () => {
    expect(mapProviderStatus('provider_paid')).toBe('captured')
  })
  it('returns unknown for unmapped statuses', () => {
    expect(mapProviderStatus('something_new')).toBe('unknown')
  })
})
```

---
name: om-integration-builder
description: Build integration provider packages for the Open Mercato Integration Marketplace. Use when creating new external integrations (payment gateways, shipping carriers, data sync connectors, communication channels, storage providers, webhook endpoints). Handles npm package scaffolding, adapter implementation, credentials, widget injection, webhook processing, health checks, i18n, and tests. Triggers on "build integration", "create integration", "add provider", "new connector", "integrate with", "add stripe/paypal/dhl/sendgrid" etc.
---

# Integration Builder

Build integration provider packages for the Open Mercato Integration Marketplace (SPEC-045). Every external integration MUST live in its own npm workspace package under `packages/<provider-package>/`.

**Steps**: 1 Pre-Flight > 2 Category > 3 Scaffold > 4 Core Files > 5 Adapter > 6 Webhooks > 7 Health Check > 8 Widgets > 9 i18n > 10 Tests > 11 Wire In > 12 Verify

---

## 1. Pre-Flight

Before writing any code:

1. **Identify the external service** (Stripe, DHL, SendGrid, S3, etc.)
2. **Read the hub's adapter contract** -- load the reference file from `references/adapter-contracts.md`
3. **Read the reference implementation** -- `packages/gateway-stripe/` is the canonical example
4. **Check existing integrations** -- `ls packages/gateway-* packages/carrier-* packages/sync-* packages/channel-* packages/storage-*`
5. **Read the external service's API docs** -- understand auth, endpoints, webhooks, status models
6. **Check for an SDK** -- prefer official SDKs over raw HTTP (`stripe`, `@aws-sdk/client-s3`, etc.)

---

## 2. Determine Integration Category

Match the external service to ONE hub category:

| Category | Hub Module | Adapter Contract | Package Prefix | Example |
|----------|-----------|-----------------|----------------|---------|
| `payment` | `payment_gateways` | `GatewayAdapter` | `gateway-` | `gateway-stripe`, `gateway-paypal` |
| `shipping` | `shipping_carriers` | `ShippingAdapter` | `carrier-` | `carrier-dhl`, `carrier-inpost` |
| `data_sync` | `data_sync` | `DataSyncAdapter` | `sync-` | `sync-medusa`, `sync-shopify` |
| `communication` | `communication_channels` | `ChannelAdapter` | `channel-` | `channel-whatsapp`, `channel-twilio` |
| `storage` | `storage_providers` | `StorageAdapter` | `storage-` | `storage-s3`, `storage-gcs` |
| `webhook` | `webhook_endpoints` | `WebhookEndpointAdapter` | `webhook-` | `webhook-zapier` |

**Package naming**: `@open-mercato/<prefix><provider>` (e.g., `@open-mercato/gateway-stripe`)
**Module naming**: `<prefix>_<provider>` in snake_case (e.g., `gateway_stripe`)

If the service spans multiple categories, use an **Integration Bundle** -- see `references/integration-templates.md` section "Bundle Integration".

---

## 3. Scaffold Package

**Directory**: `packages/<prefix><provider>/`

```
packages/<prefix><provider>/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts                    # barrel export
│   └── modules/<module_id>/
│       ├── index.ts                # module metadata
│       ├── integration.ts          # marketplace registration
│       ├── acl.ts                  # RBAC features
│       ├── setup.ts                # tenant init + env preconfiguration
│       ├── di.ts                   # DI registrar (Awilix)
│       ├── data/validators.ts      # Zod schemas
│       ├── lib/
│       │   ├── client.ts           # SDK/HTTP client factory
│       │   ├── health.ts           # health check
│       │   ├── status-map.ts       # provider -> unified status
│       │   ├── webhook-handler.ts  # webhook signature verification
│       │   └── adapters/v<ver>.ts  # versioned adapter
│       ├── workers/webhook-processor.ts
│       ├── widgets/
│       │   ├── injection-table.ts
│       │   └── injection/<name>/widget.client.tsx
│       ├── i18n/en.ts
│       └── __tests__/*.test.ts
```

See `references/integration-templates.md` section "Scaffold Package" for package.json, tsconfig.json, and index.ts templates.

---

## 4. Implement Core Files

The core files register the integration into the marketplace and wire up DI, ACL, and setup.

- **integration.ts** -- CRITICAL: marketplace registration with `IntegrationDefinition`. Defines id, category, hub, providerKey, credentials fields, health check service name, and optional API versions.
- **Bundle integration** -- for multi-integration providers (one package, many integrations sharing credentials). Uses `IntegrationBundle` + `IntegrationDefinition[]` with `bundleId`.
- **index.ts** -- module metadata (`ModuleInfo`) and ACL re-export.
- **acl.ts** -- RBAC feature declarations (`.view`, `.configure`).
- **setup.ts** -- default role features + env preconfiguration via `onTenantCreated`.
- **di.ts** -- Awilix container registrations for adapter, health check, webhook handler.

See `references/integration-templates.md` section "Core Files" for all templates including the env preconfiguration pattern.

---

## 5. Implement Adapter

Read `references/adapter-contracts.md` for the full type definitions per category. Each adapter must implement the FULL contract for its hub.

- **GatewayAdapter** (payment): createSession, capture, refund, cancel, getStatus, verifyWebhook, mapStatus
- **ShippingAdapter**: calculateRates, createShipment, getTracking, cancelShipment, verifyWebhook, mapStatus
- **DataSyncAdapter**: streamImport (async iterable), getMapping, validateConnection
- **Status mapping**: bidirectional, covers ALL known provider statuses, `'unknown'` fallback
- **Client factory**: resolve credentials fresh on every call, never store in memory

See `references/integration-templates.md` section "Adapters" for all adapter templates, status mapping, and client factory.

---

## 6. Add Webhook Processing

If the external service sends webhooks (most do), implement:

- **Webhook handler** (`lib/webhook-handler.ts`) -- signature verification + normalized `WebhookEvent` output
- **Webhook worker** (`workers/webhook-processor.ts`) -- async processing with `metadata: { queue, id, concurrency }`
- **Webhook guide** -- `helpDetails` on webhook secret credential field for admin UI setup instructions

See `references/integration-templates.md` section "Webhook Processing" for handler, worker, and guide templates.

---

## 7. Add Health Check

Implement a health check that validates real connectivity (not just credential format). The DI service name MUST match `integration.ts` -> `healthCheck.service`.

See `references/integration-templates.md` section "Health Check" for the template and DI registration.

---

## 8. Add Widget Injection

Inject configuration UI into the integration detail page:

- **Widget metadata** -- `WidgetDefinition` with lazy component import
- **Widget component** -- `'use client'` React component receiving `context`
- **Injection table** -- maps widgets to spots (`integrations.detail:tabs`, `integrations.detail:settings`, `integrations.bundle:tabs`)

See `references/integration-templates.md` section "Widget Injection" for all templates.

---

## 9. Add i18n

All user-facing strings must live in locale files. Use `useT()` client-side, `resolveTranslations()` server-side.

See `references/integration-templates.md` section "i18n" for the English translations template.

---

## 10. Add Tests

**MUST test**:
- Status mapping (all provider statuses -> unified statuses)
- Webhook signature verification (valid, invalid, expired)
- Client factory (missing credentials throw)
- Adapter methods (mock SDK calls)

### Integration Tests

Place in `__integration__/` directory following the integration-tests skill pattern:

| Test Case | Description |
|-----------|-------------|
| Create session / rate / sync | Happy path for primary adapter method |
| Webhook verification (valid) | Valid signature accepted |
| Webhook verification (invalid) | Invalid signature rejected |
| Health check (healthy) | Valid credentials return healthy |
| Health check (unhealthy) | Invalid credentials return unhealthy |
| Credential validation | Missing required fields rejected |
| Status mapping completeness | All known provider statuses mapped |

See `references/integration-templates.md` section "Tests" for unit test template.

---

## 11. Wire Into App

1. Add `import '@open-mercato/<prefix><provider>'` to `apps/mercato/src/modules.ts`
2. Add `"@open-mercato/<prefix><provider>": "workspace:*"` to `apps/mercato/package.json`
3. Run: `yarn install && npm run modules:prepare && yarn generate`
4. If env preconfiguration is supported, document env vars (required vs optional, canonical names, CLI rerun command) in the same change

---

## 12. Verification

Run after implementation: `yarn build:packages && yarn lint && yarn test --filter <pkg> && npm run modules:prepare`
Then: `yarn dev` -- integration visible at `/backend/integrations`. Test health check + credential save via admin panel.

### Self-Review Checklist

- [ ] `integration.ts` has valid `IntegrationDefinition`; secret fields use `type: 'secret'`
- [ ] Adapter implements ALL hub contract methods; status mapping covers all provider statuses + `'unknown'` fallback
- [ ] Webhook verification uses provider SDK or timing-safe HMAC; health check validates real connectivity
- [ ] No credentials stored in memory or logged -- resolve fresh from `credentials` param
- [ ] i18n: all user-facing strings in locale files; ACL features wired in `setup.ts`
- [ ] Env preconfiguration implemented when deployment-managed; `OM_INTEGRATION_<PROVIDER>_*` naming; rerunnable CLI
- [ ] Workers export `metadata: { queue, id, concurrency }`; widgets mapped to correct injection spots
- [ ] Unit tests for status mapping, webhook verification, client factory
- [ ] Package-level imports (`@open-mercato/<pkg>/...`) for cross-module references

---

## Rules

Follow all conventions from the relevant module AGENTS.md (loaded via Task Router). The rules below are specific to integration packages:

- **MUST** place every integration in its own npm workspace package under `packages/`
- **MUST NOT** add provider code inside `packages/core/src/modules/`
- **MUST** export `integration.ts` at module root for marketplace discovery
- **MUST** implement the FULL adapter contract for the chosen hub category
- **MUST** encrypt credentials at rest -- never store raw secrets; use `IntegrationCredentials` service
- **MUST** use timing-safe comparison for any manual HMAC verification
- **MUST** add health check that validates real connectivity
- **MUST** add webhook setup guide (`helpDetails`) on webhook secret credential fields
- **MUST** follow the gateway-stripe reference implementation patterns exactly
- **MUST** add provider-owned env preconfiguration when deployment automation can supply credentials or defaults
- **MUST** keep env preset logic and documentation inside the provider package; do not add provider-specific preset handling to core
- **MUST** use `OM_INTEGRATION_<PROVIDER>_*` as the primary env naming convention for new integration presets
- **MUST NOT** modify any files in `packages/core/`, `packages/ui/`, or `packages/shared/`

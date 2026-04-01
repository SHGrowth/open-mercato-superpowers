---
name: om-data-model-design
description: Design entities, relationships, and manage the migration lifecycle for Open Mercato apps. Use when planning a data model, designing entities, choosing relationship patterns, adding cross-module references, or managing database migrations. Use standalone or when dispatched by om-implement-spec for entity work. Triggers on "design entity", "data model", "add entity", "database schema", "migration", "relationship", "many-to-many", "junction table", "foreign key", "jsonb", "add column".
---

# Data Model Design

Design entities, relationships, and manage the migration lifecycle following Open Mercato conventions.

## 1. Design Workflow

When the developer describes data requirements:

1. **Clarify entities** — What are the distinct "things" being stored?
2. **Clarify fields** — What data does each entity hold?
3. **Clarify relationships** — How do entities relate? (1:1, 1:N, N:M, cross-module?)
4. **Choose patterns** — Select the right pattern for each relationship
5. **Generate** — Create entity files, validators, and migrations
6. **Verify** — Check migration output, test queries

---

## 2. Entity Design

### Standard Entity Template

```typescript
import { Entity, Property, PrimaryKey, Index, Enum } from '@mikro-orm/core'
import { v4 } from 'uuid'

@Entity({ tableName: '<entities>' })
export class <Entity> {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Index()
  @Property({ type: 'uuid' })
  organization_id!: string

  @Index()
  @Property({ type: 'uuid' })
  tenant_id!: string

  // --- Domain fields ---
  // (see Field Types section)

  // --- Standard columns ---
  @Property({ type: 'boolean', default: true })
  is_active: boolean = true

  @Property({ type: 'timestamptz' })
  created_at: Date = new Date()

  @Property({ type: 'timestamptz', onUpdate: () => new Date() })
  updated_at: Date = new Date()

  @Property({ type: 'timestamptz', nullable: true })
  deleted_at: Date | null = null
}
```

### Required Columns (Every Tenant-Scoped Entity)

| Column | Type | Purpose | Indexed |
|--------|------|---------|---------|
| `id` | `uuid` | Primary key (v4 auto-generated) | PK |
| `organization_id` | `uuid` | Tenant organization scope | Yes |
| `tenant_id` | `uuid` | Tenant scope | Yes |
| `is_active` | `boolean` | Soft active/inactive flag | No |
| `created_at` | `timestamptz` | Creation timestamp | No |
| `updated_at` | `timestamptz` | Last update (auto) | No |
| `deleted_at` | `timestamptz?` | Soft delete timestamp | No |

---

## 3. Field Types

See `references/entity-patterns.md` for the type selection guide, JSONB guidelines, enum patterns, and nullable field conventions.

---

## 4. Relationship Patterns

See `references/entity-patterns.md` for all relationship patterns (1:N, N:M, 1:1, self-referencing) with code templates.

---

## 5. Cross-Module References

**Critical rule**: NO ORM relationships (`@ManyToOne`, `@OneToMany`) between entities in different modules.

### Pattern: FK ID Only

```typescript
@Entity({ tableName: 'tickets' })
export class Ticket {
  // Reference to customer in another module — just a UUID column
  @Index()
  @Property({ type: 'uuid' })
  customer_id!: string  // FK to customers.person — NO @ManyToOne

  // Reference to assigned user in auth module
  @Index()
  @Property({ type: 'uuid', nullable: true })
  assigned_to: string | null = null  // FK to auth.user
}
```

### Fetching Related Data

To display related data from another module, use a **Response Enricher** (see `system-extension` skill):

```typescript
// data/enrichers.ts
const enricher: ResponseEnricher = {
  id: 'tickets.customer-name',
  targetEntity: 'tickets.ticket',
  async enrichMany(records, context) {
    const customerIds = [...new Set(records.map(r => r.customer_id).filter(Boolean))]
    // Fetch customer names via API or direct query
    const customers = await em.find(Person, { id: { $in: customerIds } })
    const nameMap = new Map(customers.map(c => [c.id, c.name]))
    return records.map(r => ({
      ...r,
      _tickets: { customerName: nameMap.get(r.customer_id) ?? null },
    }))
  },
}
```

### Why No ORM Relations Across Modules?

1. **Module isolation** — modules must be independently deployable and ejectable
2. **Circular dependencies** — ORM relations create tight coupling between modules
3. **Schema ownership** — each module owns its entities; cross-module ORM relations blur ownership
4. **Extension system** — UMES enrichers provide the same capability without coupling

---

## 6. Migration Lifecycle

### Creating a Migration

```bash
# 1. Modify or create entity files
# 2. Generate migration
yarn db:generate

# 3. Review the generated migration
# Check src/modules/<module_id>/migrations/Migration_YYYYMMDD_HHMMSS.ts

# 4. Apply migration (confirm with user first)
yarn db:migrate
```

### Migration Best Practices

1. **Review every migration** — auto-generated doesn't mean correct
2. **Check for unintended changes** — sometimes generators pick up unrelated diffs
3. **New columns should have defaults** — prevents breaking existing rows
4. **Never rename columns** — add new column, migrate data, remove old column (across releases)
5. **Never drop tables** — soft delete or archive first

### Adding a Column to Existing Entity

```typescript
// Add to entity with a default value
@Property({ type: 'varchar', length: 100, default: '' })
new_field: string = ''

// Or nullable for optional fields
@Property({ type: 'varchar', length: 100, nullable: true })
new_field: string | null = null
```

Then:
```bash
yarn db:generate   # Creates ALTER TABLE ADD COLUMN migration
yarn db:migrate    # Applies it
```

### Removing a Column

Don't remove columns in a single step. Instead:

1. Stop writing to the column (remove from validators and forms)
2. Make the column nullable if it isn't already
3. In a later release, drop the column via migration

---

## 7. Advanced Patterns

See `references/entity-patterns.md` for polymorphic references, ordered collections, soft delete, and audit/history table patterns.

---

## 8. Anti-Patterns

| Anti-Pattern | Problem | Correct Pattern |
|-------------|---------|-----------------|
| `@ManyToOne` across modules | Tight coupling, breaks module isolation | Store FK as `uuid` column, use enrichers |
| Storing computed values | Stale data, maintenance burden | Compute on read via enrichers or queries |
| Using `any` for JSONB fields | No type safety | Define a Zod schema, use `z.infer` |
| Manual migration SQL | Fragile, version-dependent | Use `yarn db:generate` |
| Renaming columns | Breaks existing data/queries | Add new column, migrate data, drop old |
| Missing `organization_id` | Cross-tenant data leaks | Always include and index |
| Using `varchar` without `length` | Defaults vary by DB | Always specify `length` |
| Storing arrays as comma-separated strings | Can't query, no integrity | Use `jsonb` arrays or junction tables |
| UUID FK without index | Slow joins | Always `@Index()` on FK columns |
| Nullable required fields | Data integrity issues | Use `!` assertion for required, `null` for optional |

---

## Rules

Follow all conventions from the relevant module AGENTS.md (loaded via Task Router). The rules below are specific to data model design:

- **MUST** run `yarn db:generate` after entity changes, never hand-write migrations
- **MUST** review generated migration before applying
- **MUST** use `nullable: true` with `= null` default for optional fields
- **MUST** specify `length` on all `varchar` columns
- **MUST NOT** rename or drop columns in a single release
- **MUST NOT** store sensitive data without encryption (use `findWithDecryption`)
- Use `jsonb` for flexible/nested data, proper columns for queryable/sortable data
- Use junction tables for many-to-many relationships
- Derive TypeScript types from Zod schemas, never duplicate type definitions

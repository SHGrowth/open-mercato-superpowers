# Entity Patterns

Type selection guide, relationship patterns, and advanced data modeling patterns for Open Mercato. Referenced by om-data-model-design.

## 3. Field Types

### Type Selection Guide

| Data | MikroORM Type | PostgreSQL Type | Decorator |
|------|--------------|-----------------|-----------|
| Short text (name, title) | `varchar` | `varchar(255)` | `@Property({ type: 'varchar', length: 255 })` |
| Long text (description, notes) | `text` | `text` | `@Property({ type: 'text' })` |
| Integer | `int` | `integer` | `@Property({ type: 'int' })` |
| Decimal (money, quantity) | `decimal` | `numeric(precision,scale)` | `@Property({ type: 'decimal', precision: 10, scale: 2 })` |
| Boolean | `boolean` | `boolean` | `@Property({ type: 'boolean', default: false })` |
| UUID reference | `uuid` | `uuid` | `@Property({ type: 'uuid' })` |
| Date only | `date` | `date` | `@Property({ type: 'date' })` |
| Date + time | `timestamptz` | `timestamptz` | `@Property({ type: 'timestamptz' })` |
| Enum | `varchar` | `varchar` | `@Enum({ items: () => MyEnum })` |
| Flexible JSON | `jsonb` | `jsonb` | `@Property({ type: 'jsonb', nullable: true })` |
| Array of strings | `jsonb` | `jsonb` | `@Property({ type: 'jsonb', default: '[]' })` |
| Email | `varchar` | `varchar(320)` | `@Property({ type: 'varchar', length: 320 })` |
| URL | `text` | `text` | `@Property({ type: 'text' })` |
| Phone | `varchar` | `varchar(50)` | `@Property({ type: 'varchar', length: 50 })` |

### When to Use JSONB

Use `jsonb` when:
- Schema is flexible/user-defined (custom field values, metadata, tags)
- Data is read as a whole, not queried by individual fields
- Nesting is natural (address objects, configuration maps)

Avoid `jsonb` when:
- You need to query, filter, or sort by individual fields — use proper columns
- Data has a fixed, well-known schema — use columns for type safety
- You need referential integrity — FKs can't point into JSONB

### Enum Pattern

```typescript
export enum OrderStatus {
  DRAFT = 'draft',
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  SHIPPED = 'shipped',
  DELIVERED = 'delivered',
  CANCELLED = 'cancelled',
}

@Enum({ items: () => OrderStatus })
status: OrderStatus = OrderStatus.DRAFT
```

### Nullable Fields

```typescript
// Optional field — nullable
@Property({ type: 'varchar', length: 255, nullable: true })
notes: string | null = null

// Required field — not nullable (default)
@Property({ type: 'varchar', length: 255 })
name!: string  // Use ! for required fields set during creation
```

## 4. Relationship Patterns

### One-to-Many (Same Module)

Parent entity has many children. Use `@ManyToOne` / `@OneToMany` decorators **only within the same module**.

```typescript
// Parent: Category
@Entity({ tableName: 'categories' })
export class Category {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Property({ type: 'varchar', length: 255 })
  name!: string

  @OneToMany(() => Product, product => product.category)
  products = new Collection<Product>(this)
  // ...standard columns
}

// Child: Product
@Entity({ tableName: 'products' })
export class Product {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @ManyToOne(() => Category)
  category!: Category
  // ...standard columns
}
```

### Many-to-Many (Same Module)

Use a junction (pivot) table.

```typescript
// Junction table entity
@Entity({ tableName: 'product_tags' })
export class ProductTag {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Index()
  @Property({ type: 'uuid' })
  product_id!: string

  @Index()
  @Property({ type: 'uuid' })
  tag_id!: string

  @Index()
  @Property({ type: 'uuid' })
  organization_id!: string

  @Index()
  @Property({ type: 'uuid' })
  tenant_id!: string

  @Property({ type: 'timestamptz' })
  created_at: Date = new Date()
}
```

**Junction table rules**:
- Always include `organization_id` and `tenant_id`
- Index both FK columns
- Include `created_at` for audit trail
- Add extra columns if the relationship has attributes (e.g., `quantity`, `sort_order`)

### One-to-One (Same Module)

```typescript
@Entity({ tableName: 'user_profiles' })
export class UserProfile {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Index({ unique: true })
  @Property({ type: 'uuid' })
  user_id!: string  // FK to User entity

  // Profile-specific fields
  @Property({ type: 'text', nullable: true })
  bio: string | null = null
  // ...standard columns
}
```

### Self-Referencing (Tree/Hierarchy)

```typescript
@Entity({ tableName: 'categories' })
export class Category {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Property({ type: 'uuid', nullable: true })
  parent_id: string | null = null  // Self-reference

  @Property({ type: 'varchar', length: 255 })
  name!: string

  // Optional: materialized path for efficient tree queries
  @Property({ type: 'text', default: '' })
  path: string = ''  // e.g., '/root-id/parent-id/this-id'

  @Property({ type: 'int', default: 0 })
  depth: number = 0
  // ...standard columns
}
```

## 7. Advanced Patterns

### Polymorphic References

When an entity can reference different types:

```typescript
@Entity({ tableName: 'comments' })
export class Comment {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  // Polymorphic reference
  @Index()
  @Property({ type: 'varchar', length: 100 })
  target_type!: string  // 'tickets.ticket', 'orders.order', etc.

  @Index()
  @Property({ type: 'uuid' })
  target_id!: string  // UUID of the referenced entity

  @Property({ type: 'text' })
  body!: string
  // ...standard columns
}
```

### Ordered Collections

When items have a user-defined order:

```typescript
@Entity({ tableName: 'checklist_items' })
export class ChecklistItem {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Index()
  @Property({ type: 'uuid' })
  checklist_id!: string

  @Property({ type: 'int' })
  sort_order!: number  // 0, 1, 2, 3...

  @Property({ type: 'varchar', length: 255 })
  title!: string
  // ...standard columns
}
```

### Soft Delete Pattern

All entities already include `deleted_at`. To implement soft delete:

```typescript
// In API handlers or commands:
entity.deleted_at = new Date()
entity.is_active = false
await em.flush()

// In queries — filter out deleted records:
const items = await em.find(Entity, {
  organization_id: orgId,
  deleted_at: null,  // Exclude soft-deleted
})
```

### Audit/History Table

For tracking changes to an entity:

```typescript
@Entity({ tableName: 'ticket_history' })
export class TicketHistory {
  @PrimaryKey({ type: 'uuid' })
  id: string = v4()

  @Index()
  @Property({ type: 'uuid' })
  ticket_id!: string

  @Property({ type: 'uuid' })
  changed_by!: string  // User who made the change

  @Property({ type: 'varchar', length: 50 })
  action!: string  // 'created', 'updated', 'status_changed'

  @Property({ type: 'jsonb', nullable: true })
  previous_values: Record<string, unknown> | null = null

  @Property({ type: 'jsonb', nullable: true })
  new_values: Record<string, unknown> | null = null

  @Index()
  @Property({ type: 'uuid' })
  organization_id!: string

  @Index()
  @Property({ type: 'uuid' })
  tenant_id!: string

  @Property({ type: 'timestamptz' })
  created_at: Date = new Date()
}
```

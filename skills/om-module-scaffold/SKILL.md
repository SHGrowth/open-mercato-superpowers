---
name: om-module-scaffold
description: Scaffold a new module from scratch with all required files and Open Mercato conventions. Use standalone or when dispatched by om-implement-spec for new module creation. Triggers on "create module", "new module", "scaffold module", "add module", "bootstrap module", "generate module".
---

# Module Scaffold

Create a new module with all required files following Open Mercato conventions. This skill generates the full module structure, wires it into the app, and runs required generators.

## Table of Contents

1. [Gather Requirements](#1-gather-requirements)
2. [Scaffold Structure](#2-scaffold-structure)
3. [Create Entity](#3-create-entity)
4. [Create Validators](#4-create-validators)
5. [Create API Routes](#5-create-api-routes)
6. [Create Backend Pages](#6-create-backend-pages)
7. [Add Module Metadata](#7-add-module-metadata)
8. [Add ACL & Setup](#8-add-acl--setup)
9. [Add DI Registration](#9-add-di-registration)
10. [Add Events](#10-add-events)
11. [Optional Features](#11-optional-features)
12. [Wire & Verify](#12-wire--verify)

---

## 1. Gather Requirements

Before writing any code, ask the developer:

1. **Module name** — plural, snake_case (e.g., `tickets`, `fleet_vehicles`, `loyalty_points`)
2. **Primary entity name** — singular (e.g., `ticket`, `fleet_vehicle`, `loyalty_point`)
3. **Key fields** — beyond standard columns, what data does this entity store?
4. **Relationships** — does it reference entities from other modules? (FK IDs only, no ORM relations)
5. **Features needed**:
   - [ ] CRUD API (almost always yes)
   - [ ] Backend admin pages (almost always yes)
   - [ ] Frontend public pages
   - [ ] Search indexing
   - [ ] Event publishing
   - [ ] Background workers
   - [ ] CLI commands
   - [ ] Custom fields support

If the developer provides a brief description, infer reasonable defaults and confirm.

---

## 2. Scaffold Structure

Create the directory tree under `src/modules/<module_id>/`:

```
src/modules/<module_id>/
├── index.ts                    # Module metadata + feature exports
├── acl.ts                      # Feature-based permissions
├── setup.ts                    # Tenant init, role features
├── di.ts                       # Awilix DI registrations
├── events.ts                   # Typed event declarations (if needed)
├── entities/
│   └── <Entity>.ts             # MikroORM entity class
├── data/
│   └── validators.ts           # Zod validation schemas
├── api/
│   ├── get/
│   │   └── <entities>.ts       # GET /api/<module>/<entities> (list + detail)
│   ├── post/
│   │   └── <entities>.ts       # POST /api/<module>/<entities>
│   ├── put/
│   │   └── <entities>.ts       # PUT /api/<module>/<entities>
│   └── delete/
│       └── <entities>.ts       # DELETE /api/<module>/<entities>
└── backend/
    ├── page.tsx                # List page → /backend/<module>
    ├── <entities>/
    │   ├── new.tsx             # Create page → /backend/<module>/<entities>/new
    │   └── [id].tsx            # Edit page → /backend/<module>/<entities>/<id>
```

---

## 3. Create Entity

**File**: `src/modules/<module_id>/entities/<Entity>.ts`

See `references/module-templates.md` section 3 "Create Entity" for the full template and entity rules.

---

## 4. Create Validators

**File**: `src/modules/<module_id>/data/validators.ts`

See `references/module-templates.md` section 4 "Create Validators" for the full template and rules.

---

## 5. Create API Routes

Files: `src/modules/<module_id>/api/{get,post,put,delete}/<entities>.ts`

Uses `makeCrudRoute` with one file per HTTP method. See `references/module-templates.md` section 5 "Create API Routes" for all four route templates (GET/POST/PUT/DELETE).

---

## 6. Create Backend Pages

Files: `page.meta.ts`, `page.tsx`, `<entities>/new.tsx`, `<entities>/[id].tsx` under `src/modules/<module_id>/backend/`

Uses `CrudForm` and `DataTable` from `@open-mercato/ui`. See `references/module-templates.md` section 6 "Create Backend Pages" for page metadata, list, create, and edit page templates.

---

## 7. Add Module Metadata

**File**: `src/modules/<module_id>/index.ts`

See `references/module-templates.md` section 7 "Add Module Metadata" for the template.

---

## 8. Add ACL & Setup

Files: `src/modules/<module_id>/acl.ts` and `src/modules/<module_id>/setup.ts`

See `references/module-templates.md` section 8 "Add ACL & Setup" for both templates and rules.

---

## 9. Add DI Registration

**File**: `src/modules/<module_id>/di.ts`

See `references/module-templates.md` section 9 "Add DI Registration" for the template.

---

## 10. Add Events

**File**: `src/modules/<module_id>/events.ts`

See `references/module-templates.md` section 10 "Add Events" for the template and event rules.

---

## 11. Optional Features

Optional files: `search.ts`, `translations.ts`, `cli.ts` under `src/modules/<module_id>/`.

See `references/module-templates.md` section 11 "Optional Features" for search, translations, and CLI templates.

---

## 12. Wire & Verify

### Step 1: Register in modules.ts

Add to `src/modules.ts`:

```typescript
{ id: '<module_id>', from: '@app' },
```

### Step 2: Run Generators

```bash
yarn generate          # Discover module files, update .mercato/generated/
yarn db:generate       # Create migration for new entity
```

### Step 3: Review Migration

Check the generated migration file in `src/modules/<module_id>/migrations/`. Verify:
- Table name is correct (plural, snake_case)
- All columns present with correct types
- Indexes on `organization_id`, `tenant_id`
- No unexpected changes

### Step 4: Apply & Test

```bash
yarn db:migrate        # Apply migration (confirm with user first)
yarn dev               # Start dev server
```

### Step 5: Verify

- [ ] Module appears in admin sidebar (if menu item added)
- [ ] List page loads at `/backend/<module_id>`
- [ ] Create form works at `/backend/<module_id>/<entities>/new`
- [ ] Edit form loads existing record
- [ ] Delete works from list page
- [ ] ACL features appear in role management

### Self-Review Checklist

- [ ] Module ID is plural, snake_case
- [ ] Entity class has `organization_id`, `tenant_id`, standard columns
- [ ] Validators use zod with `z.infer` for types
- [ ] All API routes export `openApi`
- [ ] Backend pages use `CrudForm` and `DataTable`
- [ ] Sidebar icon uses `lucide-react` component (not inline SVG / `React.createElement`)
- [ ] ACL features declared and wired in `setup.ts`
- [ ] Module registered in `src/modules.ts` with `from: '@app'`
- [ ] `yarn generate` run after creating files
- [ ] `yarn db:generate` run after creating entity
- [ ] No `any` types
- [ ] No hardcoded user-facing strings
- [ ] No direct ORM relationships to other modules

---

## Rules

Follow all conventions from the relevant module AGENTS.md (loaded via Task Router). The rules below are specific to scaffolding:

- **MUST** register module in `src/modules.ts` with `from: '@app'`
- **MUST** run `yarn generate` after creating module files
- **MUST** run `yarn db:generate` after creating/modifying entities
- **MUST NOT** edit `.mercato/generated/*` files manually

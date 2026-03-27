# OM Platform Capability Checklist

Use during Phase 3 (Map to Platform) to check what OM already provides before writing code.

## Update rules

This file is only updated when ALL of the following are true:
1. Mat triggered a Piotr session (checkpoint #1 or #2)
2. Piotr discovered a capability not listed here
3. Piotr pointed to the specific OM repository where the capability lives
4. Mat confirmed the capability is **implemented and merged to main or develop** on that repository (not a PR, not a branch, not planned)

Do NOT add capabilities based on roadmap, discussions, or unmerged code.

## Capabilities

| Capability | Module | What it gives you for free |
|-----------|--------|---------------------------|
| CRM (people, companies, deals, activities) | `customers` | Full CRUD, pipeline, scoped by org |
| User management, RBAC, roles | `auth` | Backend pages, API, feature-gated sidebar |
| Custom fields, custom entities | `entities` | Dynamic fields on any entity, admin UI |
| Dictionaries/taxonomies | `dictionaries` | Managed lookup tables, admin UI |
| Workflows (step-based processes) | `workflows` | Visual editor, timers, user tasks, email activities |
| Messaging/inbox | `messages` | Threaded messages, attachments, custom types, actions |
| Notifications | `notifications` | In-app bell, subscribers, custom renderers |
| Search | `search` | Fulltext, vector, faceted |
| Portal (customer-facing) | `portal` + `customer_accounts` | Login, signup, profile, RBAC, self-service |
| Widget injection | UMES | Extend any module's UI without touching its code |
| API interceptors | UMES | Modify any module's API behavior |
| Response enrichers | UMES | Add data to any module's API responses |
| Background jobs | `queue` | Workers, retry, concurrency |
| Scheduled tasks | `scheduler` | Cron-like recurring jobs |

## Red flags that you mapped wrong

| Signal | You probably missed |
|--------|-------------------|
| Building portal pages for users who need CRM | They should be `User` not `CustomerUser` |
| Custom API routes duplicating module CRUD | Use `makeCrudRoute` or existing module API |
| Custom notification subscriber | Workflows SEND_EMAIL activity |
| Hardcoded state machine in code | Workflows module |
| Custom inbox/list page | Messages module with custom message type |
| Building user management UI | Auth module backend pages |
| Custom entity CRUD | `entities` module custom entities |

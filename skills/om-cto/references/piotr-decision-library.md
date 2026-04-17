# Piotr's Decision Library

10 decision patterns extracted from Piotr Karwatka's 1,469 contributions to open-mercato/open-mercato. Each pattern includes the principle, real examples from code review, and mapping to known engineering thinkers.

---

## 1. Backward Compatibility Is Sacred

**Principle:** No column renames or removals in DB schema (additive only). No public export removal without a deprecation bridge. No event ID changes. The BC contract is non-negotiable — even if the code is otherwise correct.

**Real examples:**
- Blocked PR #1483 (hash bearer tokens): "column renames violate Backward Compatibility Contract." Provided two options: scope down or close in favor of a narrower PR.
- Blocked PR #1485 (translations): "BC violation: removed public export `emitCatalogEvent` and `emitSalesEvent`."

**Known figure:** **Sam Newman** (*Building Microservices*) — consumer-driven contracts, never break downstream consumers. Newman's rule: "If it's part of the public interface, treat changes as you would a public API version bump." Piotr applies this same discipline at the module level within a monolith.

---

## 2. Reuse Existing Helpers — Never Duplicate

**Principle:** Before writing any utility, search the codebase. If a helper exists, use it. If it's close but not quite right, extend it. The most common code review comment across the entire repo.

**Real examples:**
- PR #529: "Please use these helpers: [link to dateRanges.ts]. They were already defined within SPEC011."
- PR #604: "It seems like a duplicated helper (with `db/commands.ts`) — please use a single function to keep it DRY."
- PR #1510: Blocked for "hand-rolled boolean parsing instead of `parseBooleanWithDefault`."
- PR #444: "Shouldn't we use the queue APIs here avoiding a direct hit to bullmq?"

**Known figure:** **Martin Fowler** (*Refactoring*) — "Duplicated Code" is smell #1 in his catalog. But Piotr is pragmatic like Fowler: "I guess we don't have to refactor it here — but I wanted to point it out for the future." Not dogmatic, but the default is reuse.

---

## 3. Tests Gate the Merge — No Exceptions

**Principle:** Missing unit tests for behavior changes blocks the PR. Tests are not optional polish — they are the gate. Security-sensitive paths and behavioral changes require explicit test coverage.

**Real examples:**
- Blocked PR #1515 (auth headers): "Missing unit tests for behavior change" rated HIGH.
- Blocked PR #1493 (treeshaking): "Missing unit tests (previously requested, not addressed)" — escalated severity because it was a repeat ask.
- Approved PR #1481 (remove markitdown): Specifically praised "test regression guards are particularly strong — they make it hard for a future patch to reintroduce a shell-out path."

**Known figure:** **Kent Beck** (*Test Driven Development*) — tests as design feedback and safety net. Piotr doesn't require TDD per se, but he shares Beck's conviction that untested behavior changes are unshippable. He also echoes **Michael Feathers** (*Working Effectively with Legacy Code*): "Code without tests is bad code."

---

## 4. Decentralize Everything — Modules Self-Register

**Principle:** The bootstrap file must not know about optional modules. Modules inject their own generators, expose their own CLI seeds, register their own sidebar items. Adding a module should never require editing a central file.

**Real examples:**
- Blocked PR #938: "These imports break the app when no `enterprise` module is enabled (99.9% cases). We must find a way to inject the logic from the enterprise module so `bootstrap` does not know anything about enterprise modules."
- PR #467: "Sidebar is currently decentralized and this file centralized the settings menu — it should be automatically generated like sidebar itself."
- PR #408: "This should not be hard-coded and centralized in the dashboard module — we should be able to inject new modules here."

**Known figure:** **Sam Newman** (*Building Microservices*) — loose coupling, high cohesion. Also **Robert C. Martin** (*Clean Architecture*) — the Dependency Inversion Principle applied at the module level. Piotr's "auto-discovery" philosophy (put a file in the right place, platform finds it) mirrors Newman's "smart endpoints, dumb pipes."

---

## 5. Encryption Helpers Are a Security Invariant

**Principle:** Every query touching user data must go through `findWithDecryption` / `findOneWithDecryption`. Raw `em.find` / `em.findOne` on encrypted entities is a security violation. This is the single most repeated review comment in the repo.

**Real examples:**
- PRs #1212, #1213, #1221, #1236, #1248, #1370, #1368 — all received the same comment: "please use `findOneWithDecryption`" / "please use `findWithDecryption`."

**Known figure:** No direct match — this is Piotr's own pattern. Closest is **OWASP's "secure by default"** principle and **Tanya Janca** (*Alice and Bob Learn Application Security*) — bake security into the API surface so developers can't accidentally bypass it. Piotr's approach: make the secure path the only path.

---

## 6. Scope Discipline — One PR, One Purpose

**Principle:** A PR's title defines its scope. Changes outside that scope get called out and blocked. Bundling unrelated changes wastes reviewer attention and hides risk.

**Real examples:**
- Blocked PR #1485: "Scope creep: the title is `fix: translations`, but this PR also deletes `statusHistory.ts`, removes two emit exports, and reshuffles dependencies. None of these have anything to do with translations."
- Rejected PR #823: "No idea what's that? What problem does it solve? Which issue was about it?"
- Rejected PR #672: "I'm rejecting this PR right now as this is a major change, yet no other requests for it came so far."

**Known figure:** **Linus Torvalds** — famous for demanding small, focused patches in Linux kernel development. Also **Google's engineering practices** guide: "A CL should be a minimal, self-contained change." Piotr will merge imperfect code to keep scope tight: "I'll accept this PR for not keeping it too long open but we need to fix it in another one."

---

## 7. Extract to Shared — Make It a Platform Capability

**Principle:** When a useful pattern appears in one module, extract it to `packages/shared/lib` or `packages/ui`. Charts, date range selectors, formatters — they belong in the UI package as reusable components for the entire ecosystem.

**Real examples:**
- PR #408: "Can you please make the charts a reusable component within the `packages/ui` package so anytime someone is using a chart in OM it will be looking the same way?"
- PR #529: "Please move this helper to shared/lib as it might be useful for further usage."
- PR #185: "Let's make this filtering a reusable pattern in the core module."

**Known figure:** **Martin Fowler** — "Rule of Three" (duplicate once, extract on the third occurrence). But Piotr is more aggressive — he often requests extraction on the first occurrence if the pattern is clearly generalizable. This aligns with **DHH**'s (Ruby on Rails) "extract framework" philosophy: the platform grows by extracting real usage patterns, not by speculating.

---

## 8. Command Pattern for All Write Operations

**Principle:** All write operations must be implemented as undoable Commands. This is non-negotiable. It enables audit trails, undo functionality, and operational safety across the platform.

**Real examples:**
- PR #512: "All operations should be undoable and based on the Command pattern (check sales / commands / documents.ts for the reference)."
- PR #569: "Can we have the message oriented operations implemented as undoable Commands please?"
- PR #1111: "Please use the CRUDForm with support for custom fields + undoable commands."

**Known figure:** **Eric Evans** (*Domain-Driven Design*) — Commands as first-class domain concepts. Also **Greg Young** (CQRS/Event Sourcing) — making every state change an explicit, reversible event. Piotr's version is pragmatic: not full event sourcing, but every write operation is a Command object that knows how to undo itself.

---

## 9. Convention Over Configuration — Document It

**Principle:** Enforce naming conventions consistently. When a new convention is established, document it in `AGENTS.md` so future contributors (human and AI) follow it automatically.

**Real examples:**
- Env vars must start with `OM_` (PR #938).
- Event naming: `module.singularEntity.whatHappened` (PR #493).
- Route files: no `[verb]/route` pattern (PR #973).
- PR #347: "Maybe we should have a link to this spec in AGENTS.md? It's super useful and makes further contributions way less error prone."
- PR #273: "We should add info about how this works to AGENTS.md to keep it coherent for future modules."

**Known figure:** **DHH** (Ruby on Rails) — "Convention over Configuration" is Rails' founding principle. Piotr extends this to AI-assisted development: conventions documented in AGENTS.md become machine-readable, making AI contributors as consistent as human ones. This is a novel application that goes beyond what Fowler or DHH envisioned.

---

## 10. Decisive Priority Management — Cut Fast, Ship Pragmatically

**Principle:** Cancel features that don't serve the core mission. Reject PRs that solve problems nobody asked for. But when release timing demands it, merge with known issues and create follow-up tickets. Progress over perfection, but never at the cost of the BC contract.

**Real examples:**
- Cancelled booking module: "This feature won't be developed as Open Mercato is not a booking platform. We're switching priorities to other more crucial ERP features."
- Rejected PR #672: "This is a major change, yet no other requests for it came so far."
- Merged imperfect code: "I'll accept this PR for not keeping it too long open but we need to fix it in another one."
- Encourages contributors: "Thanks @muhammadusman586, you're doing a great job with all these fixes! Keep on doing this, man!"

**Known figure:** **Marty Cagan** (*Inspired*) — ruthless prioritization based on what customers actually need. Also **Reid Hoffman**: "If you're not embarrassed by the first version of your product, you've launched too late." Piotr balances these: ship pragmatically, but the BC contract and security invariants are never compromised for speed.

---

## Summary: Piotr's Decision Framework

When Piotr evaluates any change, he applies these checks in order:

1. **Does it break backward compatibility?** → Block.
2. **Does it duplicate existing code?** → Point to the existing helper.
3. **Does it have tests?** → Block if missing for behavior changes.
4. **Does it centralize what should be decentralized?** → Redesign.
5. **Does it handle encryption correctly?** → Security gate.
6. **Is the scope clean?** → Split if mixed concerns.
7. **Can it be extracted to shared?** → Extract if reusable.
8. **Are writes undoable?** → Command pattern.
9. **Is it documented?** → Add to AGENTS.md.
10. **Is it needed?** → Cut if nobody asked for it.

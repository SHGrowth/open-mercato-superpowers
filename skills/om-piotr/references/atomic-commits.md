# Atomic Commits — Gap Estimation (Ralph Loop)

When validating gap analysis (App Spec §4 or §6), Piotr measures each gap in **atomic commits** — not lines of code. An atomic commit is one self-contained, testable increment that a single focused development loop can deliver.

## Atomic Commit Scoring

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | Platform does it, zero commits | RBAC role in setup.ts |
| 1 | 1 commit: config/seed only | Pipeline stages in seedDefaults |
| 2 | 1-2 commits: small gap | Widget injection + i18n |
| 3 | 2-3 commits: medium gap | Entity + CRUD route + backend page |
| 4 | 3-5 commits: large gap | Multi-entity + pages + workflow definition |
| 5 | 5+ commits or external dependency | External API integration + LLM pipeline |

## What makes a good atomic commit

Each commit must be:
- **Self-contained** — builds, passes tests, app works after this commit
- **Single concern** — one entity + its route, or one widget + its injection, or one workflow definition
- **Testable** — you can verify it did what it claims

Typical atomic commit shapes:
- `setup.ts` seed (fields, pipeline stages, role features, custom entity definitions)
- Entity + CRUD route + openApi export
- Backend page (list or detail)
- Widget injection (widget.ts + component)
- Workflow JSON definition + trigger
- Worker + queue metadata
- API interceptor or response enricher
- Import/export route + parsing logic

## Subagent estimation

For gap analysis checkpoints, Piotr dispatches **subagents** to estimate each workflow or user story (depending on the Mat phase). Each subagent:

1. Takes one workflow (§4 checkpoint) or one user story group (§6 checkpoint)
2. Reads the relevant OM module AGENTS.md to understand what's available
3. Breaks the gap into atomic commits — each commit described in one line: what file(s), what pattern, what it delivers
4. Returns the commit plan

Subagent results are saved to `apps/<app>/app-spec/piotr-notes/` as:
- `commits-WF<N>.md` — per-workflow commit plan (§4 checkpoint)
- `commits-US-<N>.md` — per-story-group commit plan (§6 checkpoint)

Format:
```markdown
# Commit Plan: WF<N> — <Workflow Name>

## Commit 1: <short description>
- Scope: <app | official-module | core-module | n8n | external>
- Pattern: <setup.ts seed | entity+CRUD | widget injection | workflow JSON | worker | ...>
- Files: <list of files this commit touches>
- Delivers: <what works after this commit>
- Depends on: <commit N or "none">

## Commit 2: ...
```

## Scope column values

| Scope | Meaning | Red flag? |
|-------|---------|-----------|
| `app` | Change lives in the app repo (setup.ts, entities, routes, widgets, workers, pages) | No — this is where we build |
| `n8n` | Change lives in n8n (workflow definition, n8n-nodes enhancement) | No — external automation layer |
| `official-module` | Change requires modifying an official marketplace module | **FLAG** — needs upstream PR + approval. Plan for the dependency. Can the app extend it via UMES instead? |
| `core-module` | Change requires modifying OM core | **FLAG** — needs upstream PR + core team review + merge. This is a platform contribution, not app work. Different timeline, different approval chain. |
| `external` | Change lives outside OM entirely (scripts, third-party service config) | Document the dependency. |

**If any commit has scope `core-module` or `official-module`, FLAG IT.** These are welcome contributions — extending the platform is good. But they carry dependencies:

1. **Approval dependency:** PR to upstream repo → review by core team / module maintainer → merge. Your app can't ship this commit until upstream merges it.
2. **Timeline risk:** If upstream review takes 2 weeks, your phase is blocked for 2 weeks. Plan accordingly.
3. **Alternative check:** Can UMES extend the module from the app side instead? (interceptor, enricher, widget injection, DI override). If yes, that's `app` scope — no upstream dependency.
4. **If core/official-module is the right answer:** Flag it in the gap matrix, note the upstream dependency, and consider whether the phase can ship with a workaround while the upstream PR is in review.

## Upstream investigation for flagged commits

When Piotr flags a commit as `core-module` or `official-module`, he MUST investigate whether the needed capability is already tracked upstream. This prevents duplicate work and surfaces existing momentum.

**Check in this order:**

1. **Open specs:** Search `$OM_REPO/.ai/specs/` and `$OM_REPO/.ai/specs/enterprise/` for specs that describe the missing capability. If a spec exists, the feature is planned — reference it and note its status.
   ```bash
   grep -rl "<keyword>" $OM_REPO/.ai/specs/
   ```

2. **Open issues / PRs:** Check GitHub for existing issues or PRs on the upstream repo.
   ```bash
   gh issue list -R open-mercato/open-mercato --search "<keyword>" --state open
   gh pr list -R open-mercato/open-mercato --search "<keyword>" --state open
   ```
   For official modules:
   ```bash
   gh issue list -R open-mercato/official-modules --search "<keyword>" --state open
   ```

3. **Develop branch:** Check if it's already been implemented on `upstream/develop` but not yet released.
   ```bash
   git -C $OM_REPO log upstream/develop --oneline --grep="<keyword>" | head -10
   ```

**Report findings per flagged commit:**
```markdown
### Upstream investigation: <commit description>
- Scope: core-module | official-module
- Needed capability: <what's missing>
- Specs found: <spec ID + title, or "none">
- Issues/PRs found: <issue/PR URL + status, or "none">
- On develop branch: <yes/no + commit hash>
- Recommendation: <wait for upstream | submit PR | build app-level workaround>
```

Save findings to `apps/<app>/app-spec/piotr-notes/upstream-flags.md`.

If the capability is already specced or has an open PR, note the expected timeline. If nothing exists upstream, recommend either submitting a spec/issue (if it's a general platform need) or building an app-level workaround (if it's app-specific).

The commit plans become the input for implementation planning (brainstorming → planning → implementation).

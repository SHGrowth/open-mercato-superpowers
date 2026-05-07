# Upstream Bug Triage

Verify suspected Open Mercato core (@open-mercato/*) bugs before any downstream agent applies a workaround. om-cto verifies and drafts; the calling agent files and decides.

## When this fires

Any om-superpowers agent that finds itself thinking "OM core is broken, let me work around it" MUST route here first. Typical triggers:

- An OM core function returns wrong data, throws unexpectedly, or has a contract that doesn't match its types/docs.
- A widget injection / enricher / interceptor / event subscriber doesn't fire when the wiring looks correct.
- A migration / generator produces output that doesn't match documented behavior.
- A type signature in `@open-mercato/shared` or `@open-mercato/core` forces an `as any` cast that wouldn't be needed if the type were correct.

The pattern this prevents: silent workaround accumulation in downstream code that hides real OM bugs from the core team and creates unbounded tech debt.

## Inputs the calling agent provides

When invoking this reference, the calling agent passes:

1. **Symptom** — what they observed, in one sentence.
2. **Source location in OM core** — exact file path under `node_modules/@open-mercato/*` (or upstream path if checked out separately) and line number where the suspected bug lives.
3. **Expected vs actual** — what the docs/types/comments suggest *should* happen, vs what does happen.
4. **Reproduction** — minimal code or curl that exhibits the issue.
5. **Proposed workaround sketch** — rough shape of the patch, even if not implemented yet (file count, LOC estimate, abstractions touched).
6. **Calling agent + task** — which skill is blocked on this (e.g., "om-troubleshooter, fixing missing widget in customers detail page").

If any of these is missing, om-cto asks the calling agent to fill the gap before proceeding.

## Verification protocol

om-cto runs these checks in order. Each step can short-circuit the verdict.

### Step 1 — Read the OM core source

Read the cited file/line directly from `node_modules/@open-mercato/*` (or the upstream checkout if available). Confirm:

- The code at that location actually does what the calling agent claims it does.
- The contract (types, JSDoc, or referenced spec) actually promises what the calling agent claims it promises.

If the code matches its contract → **not-a-bug** (calling agent is using the API wrong). Return correct usage and stop.

### Step 2 — Check upstream for prior reports

Search the upstream OM repo for:

```bash
gh search issues --repo open-mercato/open-mercato "<keyword>" --state all
gh pr list --repo open-mercato/open-mercato --search "<keyword>" --state all
```

Also check the upstream `CHANGELOG.md` and recent commits on `main` / `develop` for fixes that haven't been released yet.

If a matching open issue exists → **already-reported**. Capture the issue number and any ETA hints.

If a fix is on `main` but not in the installed version → **already-reported** with note "fix landed upstream, not yet released; pin or wait."

### Step 3 — Reproduce minimally

When the call's reproduction is ambiguous, build a minimal repro inside the OM core context (not downstream). This proves the bug is in core, not downstream wiring.

If the minimal repro fails to show the bug → ask the calling agent for a tighter repro before declaring a verdict.

### Step 4 — Issue the verdict

| Verdict | Triggers |
|---------|----------|
| **not-a-bug** | Step 1 shows the code matches its contract. The calling agent is misusing the API or reading stale docs. |
| **already-reported** | Step 2 finds an open issue, an unreleased fix on main, or a duplicate PR. |
| **confirmed-new-bug** | Steps 1–3 all confirm the bug, no prior report exists. |
| **needs-clarification** | Inputs are insufficient and the calling agent has been asked once. Pause until they respond. |

## Workaround size rule

Once the verdict is `confirmed-new-bug` or `already-reported`, classify the proposed workaround:

| Class | Definition | Recommendation |
|-------|------------|----------------|
| **Minor** | ≤50 LOC, contained to a single downstream file, no new abstractions, no public API surface touched, no repetition of upstream logic. | Apply workaround AND file upstream issue. |
| **Major** | >50 LOC, or multi-file, or leaks abstractions, or forks/copies upstream module logic, or would need to be repeated each time the affected path is hit. | Wait for upstream fix. Create a downstream blocker task. Calling agent stops the current task and reports to user. |

Edge cases:

- A 30-LOC change that wraps a core helper across 5 call sites in downstream is **major** (it leaks the workaround into the call graph and makes the fix harder to remove later).
- A 60-LOC change that's a single guard at one call site, with a clear `// remove when @open-mercato/<pkg>#<issue> ships` marker, is **minor** (containable, removable).
- When in doubt → recommend major (waiting). Workaround tech debt outlasts the original deadline.

## Outputs back to calling agent

om-cto returns a structured verdict:

```yaml
verdict: not-a-bug | already-reported | confirmed-new-bug | needs-clarification
upstream_issue: <url or null>
upstream_status: <open | unreleased-fix-on-main | not-applicable>
workaround_size: minor | major | not-applicable
recommendation: apply-workaround | wait-for-upstream | use-correct-api
correct_usage: <if not-a-bug, the right way to call the API>
upstream_issue_draft: |
  <issue body — see template below — only if confirmed-new-bug>
downstream_task_draft: |
  <task body — see template below — only if recommendation is apply-workaround OR wait-for-upstream>
```

The calling agent does the actual filing.

## Upstream issue template

When verdict is `confirmed-new-bug`, draft the upstream issue body for the calling agent to file at `gh issue create --repo open-mercato/open-mercato`:

```markdown
## What's broken

<one-sentence symptom>

## Where

`<package>/<path>:<line>` — `<function or area>`

## Expected

<what the contract / docs / types promise>

## Actual

<what happens>

## Repro

```ts
<minimal code or curl>
```

## Workaround in use downstream

<Yes — link to downstream task | No — blocker, waiting for fix>

## Environment

- @open-mercato/<pkg> version: <x.y.z>
- Node: <version>
- Found by: <om-superpowers agent name> via om-cto/upstream-bug-triage
```

Lean GitHub language rule: plain English, no internal jargon, no stat tables. The reviewer reads the symptom and the repro; everything else is context.

## Downstream task template

When recommendation is `apply-workaround` or `wait-for-upstream`, draft a downstream task body for the calling agent to file at `gh issue create` in the downstream repo:

```markdown
## OM upstream blocker

<one-sentence what's blocked>

## Upstream issue

open-mercato/open-mercato#<N> — <title> (status: <open | fix-on-main-unreleased>)

## Downstream impact

<which feature / page / flow is affected>

## Action

- [ ] <Workaround applied at `<file>:<line>` — remove when upstream#<N> ships in <pkg>@<version>>
   OR
- [ ] <Wait for upstream fix; this task closes when @open-mercato/<pkg>@<version-with-fix> is installed and the workaround / pin is removed>

## Removal trigger

When `@open-mercato/<pkg>` is bumped to a version including the fix, search for `<unique marker comment from workaround>` and remove. CI will fail if the marker is left behind after the bump.
```

## Boundary — what om-cto does NOT do

- Does **not** file the upstream issue. Calling agent files via `gh`.
- Does **not** file the downstream task. Calling agent files via `gh`.
- Does **not** implement the workaround. Calling agent applies the patch if the recommendation is `apply-workaround`.
- Does **not** contact the OM core team out-of-band. The upstream issue is the channel; do not Slack / email / DM.

## What the calling agent does after the verdict

| Verdict | Recommendation | Calling agent actions |
|---------|---------------|----------------------|
| not-a-bug | use-correct-api | Apply correct usage. No filings. Continue task. |
| already-reported, fix-unreleased | apply-workaround (minor) | File downstream task with upstream link + removal trigger. Apply workaround with marker comment. Continue task. |
| already-reported, fix-unreleased | wait-for-upstream (major) | File downstream blocker task with upstream link. Stop current task. Report to user. |
| already-reported, open | apply-workaround (minor) | Same as above, plus add a +1 comment on the upstream issue if useful. |
| already-reported, open | wait-for-upstream (major) | Same as above. Comment on upstream issue with downstream impact context. |
| confirmed-new-bug | apply-workaround (minor) | File upstream issue (using draft). File downstream task referencing the new upstream issue. Apply workaround. Continue task. |
| confirmed-new-bug | wait-for-upstream (major) | File upstream issue (using draft). File downstream blocker task. Stop current task. Report to user. |

## Reporting back to user

When the recommendation is `wait-for-upstream`, the calling agent's report to the user MUST include:

- The verdict and why the workaround was classified major.
- Upstream issue URL.
- Downstream task URL.
- What the user can do to unblock (e.g., decide to absorb the major workaround anyway, escalate upstream, or re-scope the current task).

Do not silently apply a major workaround "for now." The whole point of this triage is to surface the decision to the human.

## Why this exists

Three failure modes this prevents:

1. **Silent core bugs.** Downstream patches around a real bug; OM core team never learns; the same bug bites every other downstream user.
2. **Tech debt accumulation.** Workarounds without removal triggers outlast their cause by years and make every later refactor harder.
3. **Wrong-call workarounds.** Sometimes the "bug" is a misuse of the API. Verifying first prevents shipping a workaround for behavior that was correct.

The verification hop costs a few minutes per occurrence. The alternative — the silent-workaround default — costs unbounded engineering time downstream.

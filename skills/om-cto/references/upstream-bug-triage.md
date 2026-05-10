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

## Upstream patch handoff (producer-side convention)

When the verdict is `confirmed-new-bug` AND a fix in OM core is on the table, the calling agent does NOT author the upstream patch in the current consumer-app session. It drops a self-contained task folder for the OM-side drain agent (see `upstream-task-drain.md`) to pick up. The convention is three steps the model performs with native tools — no CLI wrapper.

### Step 1 — Resolve the OM core checkout path

`Read` `~/.config/om-superpowers/handoff.json`. Expected shape:

```json
{ "om_core_path": "<absolute path to a working clone of open-mercato/open-mercato>" }
```

If the file does not exist, ask the user once for the absolute path, then `Write` the config above so future sessions don't re-ask. Do NOT proceed without a confirmed path; the drain agent on the other side needs `git`-backed isolation, so the path must be a real local checkout (with `origin = open-mercato/open-mercato` and a fork remote configured for PRs).

### Step 2 — Compose and write the task folder

Pick a slug matching `^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$`, no double hyphens. Use today's UTC date.

`Write` exactly one file: `<om_core_path>/agents/tasks/<YYYY-MM-DD>-<slug>/README.md`, composing the full substance (goal, target, hunks, tests, risks, cross-checks, provenance) inline at write time — not a skeleton-then-Edit cycle. Template below; copy verbatim and fill the angle-bracket placeholders. Keep `<om-core-checkout>` literal in the README's example commands so the drain agent (reading on a different machine) does not see a stale absolute path.

````markdown
# Task — <one-line title>

**Status:** scoped, not yet ported to OM repo, no PR opened.
**Type:** <PR — small clean fix | Issue + likely PR | Issue first, PR pending maintainer signal>
**Target branch:** off `origin/main`.

## Goal

<what the patch achieves, in plain English; before/after if behavioral>

## Target file

`<package>/<path>` at upstream sha `<sha>`.
Re-verify line anchors before applying — upstream may have moved.

## Patches to apply

See `patches.diff` in this folder if present, or compose from the goal + target above. Summary of hunks:

- Hunk 1 — <one-line what + where>
- Hunk 2 — <one-line what + where>

## Tests needed

<list of unit / integration tests the executing agent must add or extend>

## Risks / edge cases

<bounded loops, fallback paths, behavior in unrelated branches>

## Cross-checks before submitting

`gh search` commands to confirm no duplicate issue or PR exists upstream.

## Execution checklist

- [ ] `cd <om-core-checkout>`
- [ ] `git fetch origin && git checkout -b fix/<slug> origin/main`
- [ ] Apply hunks from `patches.diff` (or compose from this README)
- [ ] Write the tests listed above
- [ ] Run the existing test suite — confirm no regression
- [ ] `git diff origin/main...HEAD` review — confirm only the scoped hunks
- [ ] Commit, push to your fork remote, open PR against `origin/main`
- [ ] Paste any before/after evidence (logs, screenshots) in the PR body

## Provenance

<which consumer-app session surfaced this and the concrete repro that justifies the patch>
````

If a sketched patch already exists, also `Write` `<om_core_path>/agents/tasks/<YYYY-MM-DD>-<slug>/patches.diff` containing the verbatim diff. Otherwise omit it; the drain agent composes from the README.

### Step 3 — Stop and report

After the task folder exists, the calling agent stops the upstream-patch portion of its task and reports the folder path back to the user. The downstream workaround (if any, per the size rule above) is still applied in the consumer-app session — only the core patch is handed off.

To inspect the queue, the model can `Bash` `find <om_core_path>/agents/tasks/ -maxdepth 2 -type d -name '20*'` (incoming = top-level dirs other than `in-progress/` and `done/`). The drain protocol in `upstream-task-drain.md` defines what `in-progress/` and `done/` look like.

## Outputs back to calling agent

om-cto returns a structured verdict:

```yaml
verdict: not-a-bug | already-reported | confirmed-new-bug | needs-clarification
upstream_issue: <url or null>
upstream_status: <open | unreleased-fix-on-main | not-applicable>
workaround_size: minor | major | not-applicable
recommendation: apply-workaround | wait-for-upstream | use-correct-api
correct_usage: <if not-a-bug, the right way to call the API>
upstream_patch_task_path: <absolute path to the task folder written under <om_core_path>/agents/tasks/, or null if no upstream patch is implied>
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
- Does **not** author the upstream core patch from the consumer-app session. Calling agent composes and `Write`s the task folder per the "Upstream patch handoff" convention above; the OM-side drain agent (see `upstream-task-drain.md`) executes it.
- Does **not** contact the OM core team out-of-band. The upstream issue is the channel; do not Slack / email / DM.

## What the calling agent does after the verdict

| Verdict | Recommendation | Calling agent actions |
|---------|---------------|----------------------|
| not-a-bug | use-correct-api | Apply correct usage. No filings. Continue task. |
| already-reported, fix-unreleased | apply-workaround (minor) | File downstream task with upstream link + removal trigger. Apply workaround with marker comment. Continue task. |
| already-reported, fix-unreleased | wait-for-upstream (major) | File downstream blocker task with upstream link. Stop current task. Report to user. |
| already-reported, open | apply-workaround (minor) | Same as above, plus add a +1 comment on the upstream issue if useful. |
| already-reported, open | wait-for-upstream (major) | Same as above. Comment on upstream issue with downstream impact context. |
| confirmed-new-bug | apply-workaround (minor) | File upstream issue (using draft). Compose and `Write` the task folder per the "Upstream patch handoff" convention above. File downstream task referencing the upstream issue + the task folder path. Apply workaround. Continue task. |
| confirmed-new-bug | wait-for-upstream (major) | File upstream issue (using draft). Compose and `Write` the task folder per the "Upstream patch handoff" convention above. File downstream blocker task. Stop current task. Report to user, including the task folder path. |

## Reporting back to user

When the recommendation is `wait-for-upstream`, the calling agent's report to the user MUST include:

- The verdict and why the workaround was classified major.
- Upstream issue URL.
- Downstream task URL.
- Path to the task folder written under `<om-core-checkout>/agents/tasks/` so the next session (the OM-side drain agent) can pick it up.
- What the user can do to unblock (e.g., decide to absorb the major workaround anyway, escalate upstream, or re-scope the current task).

Do not silently apply a major workaround "for now." The whole point of this triage is to surface the decision to the human.

## Why this exists

Three failure modes this prevents:

1. **Silent core bugs.** Downstream patches around a real bug; OM core team never learns; the same bug bites every other downstream user.
2. **Tech debt accumulation.** Workarounds without removal triggers outlast their cause by years and make every later refactor harder.
3. **Wrong-call workarounds.** Sometimes the "bug" is a misuse of the API. Verifying first prevents shipping a workaround for behavior that was correct.
4. **Cross-repo patch contamination.** Upstream patches written from a consumer-app session land in the wrong working directory, mix with downstream diffs, or get committed to the wrong remote. The producer convention (this reference) and the consumer drain protocol (`upstream-task-drain.md`) keep the two repos cleanly separated.

The verification hop costs a few minutes per occurrence. The alternative — the silent-workaround default — costs unbounded engineering time downstream.

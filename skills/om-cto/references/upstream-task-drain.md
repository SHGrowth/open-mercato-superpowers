# Upstream Task Drain

Sibling to `upstream-bug-triage.md`. Where bug-triage is the **producer** path (consumer-app session drops a task with `om-handoff`), this is the **consumer** path: an agent session running against the OM core checkout works through the queue, lands PRs upstream, and marks tasks done.

## When this fires

A session running with `cwd` inside the OM core checkout — typically invoked by the user with "drain the upstream queue" or "pick up the next task from agents/tasks/" — routes here.

The session is allowed to edit OM core, run OM tests, and push to a fork remote. A consumer-app session is NOT and routes through `upstream-bug-triage` instead.

## Queue layout

```
<om-core-checkout>/agents/tasks/
  YYYY-MM-DD-<slug>/        ← incoming (dropped by om-handoff)
  in-progress/
    YYYY-MM-DD-<slug>/      ← claimed; an agent (or human) is working it
  done/
    YYYY-MM-DD-<slug>/      ← landed; sibling resolution.md describes outcome
```

Use `bin/om-task-list` to inspect the queue without listing directories by hand.

## Claim protocol

```bash
cd <om-core-checkout>
mkdir -p agents/tasks/in-progress
git mv agents/tasks/YYYY-MM-DD-<slug> agents/tasks/in-progress/
git commit -m "claim: <slug>"
```

The `git mv` + commit is the lock. If two drain sessions race, the second one's `git mv` fails because the source no longer exists — that's the intended behavior. No file-based locking needed.

If the source is already under `in-progress/` when you look, do NOT touch it. Pick a different incoming task.

## Work protocol

1. Read the task folder's `README.md` end-to-end. If goal, target file, or hunks are unclear, STOP — comment back on the originating session's issue (linked in Provenance) rather than guessing.
2. Re-verify the line anchors the README cites against the current upstream source. The README was written at a previous sha; upstream may have moved. If anchors no longer match, update the README in-place with the new sha + line numbers and commit before proceeding ("re-verify: <slug> against <new-sha>").
3. Branch off `origin/main`: `git fetch origin && git checkout -b fix/<slug> origin/main`.
4. Apply hunks from `patches.diff` if present, or write the patch from scratch using the README as spec.
5. Write the tests the README lists. If the README says "tests needed" but doesn't list specific cases, add coverage for: the bug repro, one regression case, and the contract the patch restores.
6. Run the existing test suite. Fix anything you broke; do not silence failing tests.
7. `git diff origin/main...HEAD` review — confirm only the scoped hunks + tests, nothing stray.
8. Commit with a conventional message (e.g., `fix(<package>): <one-line>`). Push to your fork remote. Open a PR against `origin/main` with title composed from the README's Goal (one-line, conventional-commit style) and body composed from Goal + Provenance + a link back to the upstream issue.
9. Paste before/after evidence (logs, screenshots, the originating session's repro output) in the PR body.

## Done protocol

```bash
cd <om-core-checkout>
git mv agents/tasks/in-progress/YYYY-MM-DD-<slug> agents/tasks/done/
```

Add a sibling `resolution.md` next to the moved README:

```markdown
# Resolution — <slug>

**Outcome:** <merged | open-pr-pending-review | rejected-upstream | not-a-bug-after-all>
**Upstream PR:** open-mercato/open-mercato#<N>
**Released in:** @open-mercato/<pkg>@<x.y.z> (or "pending release" if PR is merged but not released)
**Closed:** YYYY-MM-DD

## What landed

<one-sentence summary of the merged change>

## What changed vs the original task

<if anything: scope changes, additional hunks, anchors updated, etc.>

## Removal trigger for downstream

When `@open-mercato/<pkg>` is bumped to the released version, search downstream for `<unique marker comment from the workaround, if any>` and remove. The originating downstream task (linked from Provenance) tracks this.

## Originating context

- Provenance from the original README: <copy the line>
- Drained by: <agent session id or human name>
```

Commit the move + the resolution: `done: <slug> (open-mercato/open-mercato#<N>)`.

## Rejection / pushback path

If after step 1 (read) or step 2 (re-verify) you decide the task is wrong — repro doesn't reproduce, fix is misguided, anchors are gone — do NOT silently delete it. Move to `done/` as above with `resolution.md` outcome `rejected-upstream` or `not-a-bug-after-all`, and explain in 2–3 sentences. Then comment back on the originating session's issue so the consumer-app side knows to remove any workaround they applied in anticipation of the fix.

## Boundary — what this protocol does NOT do

- Does **not** authorize rewriting the task's scope mid-flight without comment. If the patch grows past what the README specified, stop and re-scope explicitly (commit a `re-scope: <slug>` update to the README first, then continue).
- Does **not** skip the test suite. A green run is the price of admission for an upstream PR; a flake-prone or untested patch fails the contract this protocol exists to uphold.
- Does **not** push directly to `origin/main`. PRs only.

## Why this exists

Two failure modes this prevents:

1. **Silent abandonment.** A claimed task that sits in `in-progress/` for weeks with no commits is a signal the drain agent died or the task was over-scoped. The mtime + `om-task-list` view make this visible.
2. **Drift between consumer and core.** Without a `resolution.md` linking back to the originating downstream task, there's no automatic way for the consumer side to know when the workaround is removable. The resolution file IS the ack channel.

The producer-consumer split only works if both sides honor the queue. This protocol is the consumer-side half.

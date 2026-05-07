# Bootstrap — `/om-orchestrate init`

Prepares a fresh OM repo to host the orchestration fleet. Idempotent — running it twice does not re-create labels or overwrite the config; it surfaces drift instead.

## Steps

### 1. Pre-checks

```bash
# gh auth
gh auth status || abort "Run 'gh auth login' first."

# Repo detection — orchestrate works only inside a git repo with a GitHub remote
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || abort "Not a git repo."
gh repo view --json nameWithOwner >/dev/null 2>&1 || abort "No GitHub remote detected."
```

### 2. Detect project shape

Look for hints to populate the config stub:
- `package.json` test scripts — find a `test:integration` or `test:e2e` candidate; default to none if absent.
- `.ai/runs/` directory — if exists, use it; otherwise default `paths.run_plans`.
- `.ai/specs/` directory — same.
- `app-spec/app-spec.md` — same.
- Default base branch: `git symbolic-ref refs/remotes/origin/HEAD --short | sed 's@^origin/@@'`. Fall back to `develop` if not set, then `main`.

### 3. Write `.ai/orchestration.yml`

If the file already exists, **do not overwrite**. Diff against the template; print any drift and ask the user what to do via `AskUserQuestion`.

If absent, write the stub from `references/orchestration-yml.md` § Template, populated with detected values. Comments preserved so the user knows what to edit.

### 4. Create labels

The 11 labels needed:

```bash
LABELS=(
  "status:backlog:#cccccc:Issue created, deps not yet met"
  "status:ready:#0e8a16:Ready for a coding agent"
  "status:coding:#1d76db:Coding agent active"
  "status:needs-e2e:#fbca04:Coding done; e2e queue should pick up"
  "status:e2e-running:#fef2c0:E2E singleton processing"
  "status:e2e-passed:#0e8a16:Tests green; resume to review"
  "status:e2e-failed:#d93f0b:Tests red; resume to fix"
  "status:review:#5319e7:Review pass running"
  "status:review-clean:#0e8a16:Review clean; ready to merge"
  "status:blocked:#b60205:Blocker - needs human"
  "human-review:#000000:Pause - do not advance until removed"
)

for entry in "${LABELS[@]}"; do
  IFS=':' read -r name color description <<< "$entry"
  gh label create "$name" --color "$color" --description "$description" --force 2>/dev/null || true
done
```

`--force` makes the operation idempotent (updates color/description if the label exists).

### 5. Verify env vars

Read `e2e.required_env` from the freshly-written config. For each:
- If set in shell → green checkmark.
- If unset → warn (don't block): *"Env var X is required for e2e tests. Set it before running `/om-orchestrate run` or e2e jobs will fail."*

### 6. Print summary

Lean output. No stat tables. Example:

```
Orchestration ready.

  Repo:    matgren/oss-prm
  Labels:  11/11 created
  Config:  .ai/orchestration.yml
  Auth:    gh OK (logged in as matgren)
  Env:     1 required var detected, 1 set

Next: /om-orchestrate run app-spec/app-spec.md
```

## Re-running init

If labels exist with the same names but different colors, `--force` updates them (silent). If the user has customized labels, the customization is overwritten — this is acceptable for a bootstrap UX, but document it: *"`init` is idempotent on label names but will reset color/description to canonical."*

If `.ai/orchestration.yml` exists with drift from the current schema, present a diff and ask the user via `AskUserQuestion` before any change. Never silently rewrite user config.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `gh auth status` fails | Not logged in | `gh auth login` |
| `gh label create` 403 | Token lacks `repo` scope | `gh auth refresh -s repo` |
| `gh repo view` fails | No `origin` remote, or remote isn't GitHub | Set up the remote, or document how to point at the right repo via `gh repo set-default` |
| `.ai/orchestration.yml` already drifted | User edited the file; schema changed in a release | Print diff, ask user to reconcile |

# om-claude-plugin

Claude Code plugin for Open Mercato developers. 10 skills covering the full OM developer lifecycle: spec writing, platform challenge, UI review, implementation, and code review.

## Install

~~~
/plugin marketplace add SHGrowth/om-claude-plugin
/plugin install om-claude-plugin@om-claude-plugin
~~~

### Prerequisites

- [Claude Code](https://claude.ai/code) (or Cursor with plugin support)
- [superpowers](https://github.com/obra/superpowers) plugin — OM skills reference superpowers workflows (brainstorming, writing-plans, executing-plans, TDD)
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated, for om-piotr platform search

## Skills

### Spec & Design

| Skill | When to use |
|-------|-------------|
| `om-mat` | Starting a new feature, module, or spec — business context, workflows, user stories |
| `om-piotr` | Before any code — gap analysis, "does OM already do X?", atomic commit estimation |
| `om-krug` | After UI architecture is defined — navigation, task completion, cognitive load review |

### Implementation

| Skill | When to use |
|-------|-------------|
| `om-spec-writing` | Creating architecturally compliant specifications |
| `om-pre-implement-spec` | Before implementation — backward compatibility impact, risk analysis |
| `om-implement-spec` | Multi-phase spec implementation with coordinated subagents |
| `om-integration-tests` | Creating or running Playwright integration tests |
| `om-integration-builder` | Building provider packages (payment, shipping, data sync) |
| `om-backend-ui-design` | Designing backend UI pages within OM framework |

### Quality

| Skill | When to use |
|-------|-------------|
| `om-code-review` | After completing a feature, before merging — CI/CD gate + full OM checklist |

### Developer Flow

~~~
om-mat --> om-piotr --> om-krug --> om-spec-writing --> om-pre-implement-spec --> om-implement-spec --> om-code-review
~~~

## How superpowers + OM skills work together

Superpowers provides the **workflow engine** (brainstorming, planning, TDD, debugging). OM skills provide **domain knowledge** (what OM modules exist, how to review OM code, how to write OM specs). They interleave:

~~~
1. User: "Build a feature for OM"
   │
2. superpowers:brainstorming          ← superpowers drives the design process
   │  └─ invokes om-mat               ← OM skill: defines spec with domain model
   │       └─ dispatches Vernon        ← DDD challenger (subagent within om-mat)
   │       └─ invokes om-piotr         ← OM skill: "does OM already do this?"
   │       └─ invokes om-krug          ← OM skill: UI architecture review
   │
3. superpowers:writing-plans           ← superpowers creates implementation plan
   │  └─ invokes om-pre-implement-spec ← OM skill: BC impact, risk analysis
   │  └─ invokes om-spec-writing       ← OM skill: architectural compliance
   │
4. superpowers:executing-plans         ← superpowers executes plan step by step
   │  └─ invokes om-implement-spec     ← OM skill: multi-phase implementation
   │  └─ superpowers:tdd              ← superpowers: red-green-refactor cycle
   │       └─ invokes om-integration-tests  ← OM skill: Playwright tests
   │
5. superpowers:requesting-code-review  ← superpowers initiates review
   └─ replaced by om-code-review      ← OM skill: CI/CD gate + full OM checklist
~~~

**Rule of thumb:** superpowers decides *how* to work. OM skills decide *what* to build and *what to check*.

| Phase | Superpowers skill | OM skill (domain) |
|-------|------------------|-------------------|
| Design | `brainstorming` | `om-mat`, `om-piotr`, `om-krug` |
| Planning | `writing-plans` | `om-spec-writing`, `om-pre-implement-spec` |
| Implementation | `executing-plans`, `tdd` | `om-implement-spec`, `om-integration-tests`, `om-integration-builder`, `om-backend-ui-design` |
| Review | `requesting-code-review` | `om-code-review` (replaces generic reviewer) |

## How it works

The plugin auto-detects OM projects on session start by looking for:
- `@open-mercato/` dependency in `package.json`
- "Open Mercato" in `AGENTS.md`
- `.ai/` directory

When detected, it injects the list of available OM skills into the session context. Skills are invocable anytime via the Skill tool (e.g., `skill: "om-code-review"`).

## Syncing OM platform skills

7 of the 10 skills are vendored from [open-mercato/open-mercato](https://github.com/open-mercato/open-mercato). To update them:

```bash
# Fetch latest skills from OM repo (develop branch)
bash scripts/sync-om-skills.sh

# Review what changed
git diff skills/

# Commit the update
git add skills/ && git commit -m "chore: sync OM skills from open-mercato/open-mercato@$(head -c7 skills/.om-sync-version)"

# Tag a release
git tag vX.Y.Z
git push origin main --tags
```

The sync script:
1. Fetches each skill's `SKILL.md` and `references/` from `raw.githubusercontent.com`
2. Renames the `name:` field in frontmatter to add `om-` prefix
3. Saves the source commit SHA to `skills/.om-sync-version`

Run this before each plugin release.

## License

MIT

---
name: om-toolkit-review
description: Use when auditing the OM superpowers skill corpus for context waste, rule duplication, trigger overlap, stale references, or structural drift. Triggers on "review skills", "audit toolkit", "skill health check", "are skills bloated", "context budget".
---

# Toolkit Review

Audit the OM superpowers skill corpus for context efficiency, structural health, and upstream alignment. Produces a prioritized report with concrete fixes.

## When to Run

- After adding or significantly editing a skill
- Periodic hygiene (monthly or after a burst of skill work)
- When conversations feel slow or context-starved during orchestrator chains
- Before cutting a new plugin release

## Audit Dimensions

Run all dimensions. Report findings per dimension with severity (Critical / High / Medium / Low).

### 1. Size Budget

Measure every SKILL.md and reference file. Context is finite — every token in a skill is a token not available for code.

```bash
find skills -name "*.md" -exec wc -c {} \; | sort -rn
find skills -name "SKILL.md" -exec wc -c {} + | tail -1
find skills -name "*.md" -exec wc -c {} + | tail -1
```

**Thresholds:**

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Single SKILL.md | < 12KB | 12-20KB | > 20KB |
| SKILL.md + its references | < 25KB | 25-40KB | > 40KB |
| Total corpus (all SKILL.md) | < 150KB | 150-250KB | > 250KB |
| Total corpus (all .md) | < 250KB | 250-350KB | > 350KB |

**Why these thresholds:** A full orchestrator chain (om-cto → implement-spec → code-review → tests) can load 5-8 skills. At 20KB each, that's 100-160KB of skill text before any code is read. On 200K-token models, skill instructions should stay under ~25% of context.

### 2. Rule Duplication vs. Upstream

OM platform conventions live in `om-reference/AGENTS.md` and per-module AGENTS.md files. Skills that re-state these rules waste context and create maintenance drift.

**Process:**
1. Read `om-reference/AGENTS.md` — extract the key rules (tenant isolation, naming, exports, etc.)
2. For each SKILL.md, grep for rules that duplicate upstream AGENTS.md content
3. Flag any rule that appears in 3+ skills verbatim

**Common duplicates to check:**

| Rule pattern | Grep for |
|-------------|----------|
| Tenant isolation | `organization_id.*tenant_id`, `tenant.scop` |
| No cross-module ORM | `cross-module.*ORM`, `ManyToOne.*across`, `FK IDs only` |
| openApi export | `export.*openApi`, `MUST export.*openApi` |
| CrudForm/DataTable only | `CrudForm.*never custom`, `DataTable.*never.*table` |
| No `any` types | `No.*any.*zod`, `z\.infer` |
| i18n rules | `useT\(\).*hardcoded`, `resolveTranslations` |
| ACL feature format | `id.*title.*module` |
| Event naming | `module\.entity\.past_tense` |
| BC 13-category table | `contract surface`, `13.*categories` |

**Verdict:**
- Rule in 1 skill + upstream AGENTS.md → **redundant**, remove from skill
- Rule in 3+ skills but NOT in upstream → candidate for a shared `references/om-coding-rules.md` (create when needed)
- Rule in 1 skill only → fine, leave it

### 3. Template-to-Logic Ratio

Skills should be decision logic + workflow. Code templates belong in `references/`.

**Process:** For each SKILL.md over 15KB, estimate:
- Lines of TypeScript/TSX code blocks
- Lines of decision logic, workflow steps, rules

**Threshold:** If code templates exceed 50% of SKILL.md, they should move to a skill-specific `references/templates.md` (create per skill when needed).

**Check which skills follow the right pattern:**
- om-cto: lean task router in SKILL.md, mode workflows in references — **ideal pattern**
- Compare other skills against this pattern

### 4. Trigger Overlap

Multiple skills matching the same user intent causes wrong-skill invocation.

**Process:**
1. Extract all `description:` fields from SKILL.md frontmatter
2. Build a trigger matrix: for common user phrases, which skills match?

**Test phrases:**

| User says | Should trigger | Should NOT trigger |
|-----------|---------------|-------------------|
| "build this feature" | om-cto (advisory) | om-product-manager |
| "implement the spec" | om-cto (impl orchestrator) | om-product-manager |
| "review this code" | base code-review (synced) | om-cto |
| "create a new module" | om-module-scaffold | om-cto |
| "extend the customers module" | om-system-extension | om-eject-and-customize |
| "write a spec" | om-cto (spec orchestrator) | om-product-manager |
| "add an entity" | om-data-model-design | om-module-scaffold |
| "design the UI" | om-backend-ui-design | om-ux |
| "run tests" | om-integration-tests | om-cto |
| "this doesn't work" | om-troubleshooter | — |

**Verdict:** If two skills both match a phrase, their descriptions need disambiguation. One should clearly say "Use BEFORE X" and the other "Use AFTER X" or "Use WHEN X already exists."

### 5. Stale References

Skills reference files, paths, variables that may not exist or have moved.

**Process:**
```bash
# Find $OM_REPO references (undefined in plugin context)
grep -rn '\$OM_REPO' skills/

# Find .ai/skills/codex/ paths (old structure)
grep -rn '\.ai/skills/codex' skills/

# Find references to files — verify they exist
grep -rnoE 'references/[a-z0-9_-]+\.md' skills/ | while read match; do
  file=$(echo "$match" | sed 's/.*://')
  dir=$(dirname "$(echo "$match" | cut -d: -f1)")
  [ ! -f "$dir/$file" ] && echo "MISSING: $dir/$file (referenced from $match)"
done
```

Also check:
- Cross-skill references (do om-cto dispatch contexts reference base skills correctly?)
- `om-reference/` paths (do referenced AGENTS.md files exist in vendored copy?)

### 6. Chain Context Explosion

When om-cto orchestrates, it chains multiple skills. Estimate total context for each chain.

**Process:** Trace the orchestrator chains:

```
Chain A (Spec Orchestrator):
  om-cto SKILL.md + spec-orchestrator.md + base spec-writing + base pre-implement-spec
  + conditional: om-data-model-design, om-system-extension

Chain B (Implementation Orchestrator — per spec):
  om-cto SKILL.md + impl-orchestrator.md + base implement-spec + base code-review + base integration-tests
  + conditional: om-module-scaffold, om-backend-ui-design,
                 om-system-extension, om-troubleshooter

Chain C (Full pipeline — Chain A then Chain B per spec):
  Sum of all above
```

For each chain, sum the SKILL.md sizes of loaded skills. Compare against context budget (target: < 25% of model context for skills).

**Thresholds:**

| Chain | Budget (200K model) | Budget (1M model) |
|-------|--------------------|--------------------|
| Single skill invocation | < 30KB | < 30KB |
| Orchestrator chain | < 100KB | < 150KB |
| Full pipeline | < 150KB | < 250KB |

### 7. System Prompt Coverage

Skills exist on disk but may not be listed in the Claude Code system prompt (plugin registration).

**Process:**
```bash
# List all skill directories
ls skills/ | sed 's/^/open-mercato-superpowers:/'

# Compare against what appears in session system-reminder
# (manually check — the skill listing is in the system prompt)
```

**Classify each skill:**
- **User-invocable:** Listed in system prompt, user can invoke directly
- **Internal:** Not listed, only invoked by other skills
- **Orphaned:** Exists on disk, not referenced by any other skill

Internal skills are fine if intentional. Document which are which.

### 8. Skill-to-Skill Consistency

Check that skills that reference each other agree on conventions.

**Process:**
- Do om-cto's dispatch context sections match what the base OM skills actually expect?
- Do pipeline assumptions (impl-orchestrator Pipeline Lock) match what base skills actually do?
- Are synced base skills up to date with OM core develop?

## Output Format

```markdown
# Toolkit Audit — {date}

## Budget Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total SKILL.md | {X}KB | {green/yellow/red} |
| Total corpus | {X}KB | {green/yellow/red} |
| Largest SKILL.md | {name} ({X}KB) | |
| Estimated full-chain load | {X}KB | {green/yellow/red} |

## Findings

### Critical
{Findings that actively degrade model performance or cause wrong behavior}

### High
{Findings that waste significant context or create maintenance risk}

### Medium
{Structural improvements, minor waste}

### Low
{Polish, nice-to-have}

## Duplication Report

| Rule | Appears in (skills) | Also in upstream AGENTS.md? | Action |
|------|--------------------|-----------------------------|--------|

## Trigger Overlap Report

| Phrase | Matching skills | Correct skill | Fix needed? |
|--------|----------------|---------------|-------------|

## Stale References

| File | Line | Reference | Status |
|------|------|-----------|--------|

## Recommendations (prioritized)

| # | Fix | Impact | Effort |
|---|-----|--------|--------|
```

## Rules

- MUST run all 8 audit dimensions — no shortcuts
- MUST produce the structured output format
- MUST check actual file sizes, not estimates
- MUST verify stale references against the filesystem
- MUST trace chains by reading skill cross-references, not from memory
- MUST NOT modify any skill files — this skill is audit-only
- MUST NOT skip upstream comparison — rule duplication vs AGENTS.md is the highest-value check
- Present findings to the user before proposing any changes

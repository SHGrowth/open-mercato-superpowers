#!/usr/bin/env python3
"""Transform upstream OM create-app AGENTS.md template into plugin canonical.

Reads upstream raw content from packages/create-app/agentic/shared/AGENTS.md.template,
applies the routing transform map (rewrites `.ai/skills/<name>/SKILL.md`
references to `om-superpowers:om-<canonical>` invocations), drops table rows
and prose blocks that reference skills with no plugin equivalent (auto-*-loop,
auto-fix-github, auto-upgrade-0.4.10-to-0.5.0, trim-unused-modules), substitutes
the {{PROJECT_NAME}} placeholder, prepends a versioned plugin marker, writes
the result.

Usage:
  python3 transform-agents-template.py <src> <dest> <plugin-version>
"""
import re
import sys
from pathlib import Path


# Routing transform: upstream skill name → plugin invocation phrase.
# The phrase replaces the entire `.ai/skills/<name>/SKILL.md` reference,
# wrapped in backticks at the call site.
ROUTING_MAP = {
    "module-scaffold":     "om-superpowers:om-implement-spec` (router → module-scaffold)",
    "data-model-design":   "om-superpowers:om-implement-spec` (router → data-model-design)",
    "backend-ui-design":   "om-superpowers:om-ds-guardian` (router → backend-ui-design)",
    "integration-builder": "om-superpowers:om-implement-spec` (router → integration-builder)",
    "system-extension":    "om-superpowers:om-implement-spec` (router → system-extension)",
    "eject-and-customize": "om-superpowers:om-implement-spec` (router → system-extension/eject.md)",
    "troubleshooter":      "om-superpowers:om-troubleshooter`",
    "code-review":         "om-superpowers:om-code-review`",
    "spec-writing":        "om-superpowers:om-cto` (router → spec-writing)",
    "implement-spec":      "om-superpowers:om-implement-spec`",
    "integration-tests":   "om-superpowers:om-integration-tests`",
    "auto-create-pr":      "om-superpowers:om-auto-create-pr`",
    "auto-continue-pr":    "om-superpowers:om-auto-continue-pr`",
    "auto-review-pr":      "om-superpowers:om-auto-review-pr`",
}

# Skills with no plugin counterpart. Any line referencing one of these
# in a `.ai/skills/<name>/` path is dropped from the output.
DROP_SKILLS = {
    "auto-create-pr-loop",
    "auto-continue-pr-loop",
    "auto-fix-github",
    "auto-upgrade-0.4.10-to-0.5.0",
    "trim-unused-modules",
}

# Multi-line prose blocks to drop entirely, keyed by a unique starter substring.
# The value is the substring that marks the END of the block (exclusive — the
# line containing it survives). Blocks are matched line-by-line; the first line
# containing the start substring begins drop mode, drop mode ends when a line
# containing the end substring is reached. Use carefully — order matters.
DROP_BLOCKS = [
    # Critical Rule #8 — predicated on trim-unused-modules being available.
    # The Dashboards fallback rule (immediately after) survives because it's
    # not predicated on the trim skill and remains useful when the user
    # disables dashboards manually.
    {
        "start": "8. **After the user adds a new module, offer to trim classic mode.**",
        "end": "**Dashboards fallback rule.**",
        "renumber_after": True,  # renumber subsequent rules 9→8, 10→9, etc.
    },
]

# Surgical inline edits for lines that survive other transforms but mention
# dropped-skill names in prose (slash-command examples, parenthetical asides).
# Applied after replace_skill_refs but before output. Each tuple is (find, replace).
PROSE_REPLACEMENTS = [
    # "Invoke these from the Claude Code CLI as slash commands, for example
    #  `/auto-create-pr ...` or `/auto-fix-github 42`." — drop the second example
    (" or `/auto-fix-github 42`", ""),
    # Dashboards fallback rule's parenthetical "(or the `trim-unused-modules`
    # skill)" is dead under the new policy — user-driven disable is what
    # triggers the fallback now.
    (" (or the `trim-unused-modules` skill)", ""),
]


def replace_skill_refs(line: str) -> str:
    """Rewrite `.ai/skills/<name>/SKILL.md` and `.ai/skills/<name>/references/...` references."""
    # Pattern: `.ai/skills/<name>/SKILL.md` → invoke clause
    def skill_sub(m: re.Match) -> str:
        name = m.group(1)
        if name in ROUTING_MAP:
            return "invoke `" + ROUTING_MAP[name]
        # Unknown skill — leave the original reference for manual review
        return m.group(0)

    line = re.sub(r"`\.ai/skills/([a-z0-9_.-]+)/SKILL\.md`", skill_sub, line)

    # Pattern: `.ai/skills/<name>/references/<sub>` → invoke + loads sub
    def subref_sub(m: re.Match) -> str:
        name = m.group(1)
        sub = m.group(2)
        if name in ROUTING_MAP:
            base = ROUTING_MAP[name].split("`")[0]  # strip the trailing backtick + suffix
            return f"invoke `om-superpowers:{base.split(':')[1] if ':' in base else base}` (loads {name}/{sub})"
        return m.group(0)

    line = re.sub(r"`\.ai/skills/([a-z0-9_.-]+)/references/([a-z0-9_./-]+)`", subref_sub, line)

    return line


def should_drop_line(line: str) -> bool:
    """Return True if the line references a skill we're dropping."""
    for skill in DROP_SKILLS:
        if f".ai/skills/{skill}/" in line:
            return True
    return False


def transform(src_text: str) -> str:
    """Apply all transforms to upstream content."""
    lines = src_text.splitlines()
    out: list[str] = []

    in_drop_block: dict | None = None
    pending_renumber = False

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if a drop block starts here
        if in_drop_block is None:
            for block in DROP_BLOCKS:
                if block["start"] in line:
                    in_drop_block = block
                    if block.get("renumber_after"):
                        pending_renumber = True
                    break

        # If we're in a drop block, check if it ends on this line
        if in_drop_block is not None:
            if in_drop_block["end"] in line:
                # End line stays, drop mode ends
                in_drop_block = None
            else:
                # Drop this line
                i += 1
                continue

        # Drop any line that references a dropped skill
        if should_drop_line(line):
            i += 1
            continue

        # Apply skill-ref replacements
        line = replace_skill_refs(line)

        # Apply surgical prose substitutions for surviving-skill mentions in prose
        for find, repl in PROSE_REPLACEMENTS:
            if find in line:
                line = line.replace(find, repl)

        # Renumber subsequent numbered Critical Rules if a rule was dropped
        # Pattern: `N. **` where N is a digit and N > dropped_rule_number
        if pending_renumber:
            m = re.match(r"^(\d+)\. \*\*", line)
            if m:
                old_n = int(m.group(1))
                # We dropped rule 8, so 9→8, 10→9, 11→8, 12→11
                if old_n >= 9:
                    new_n = old_n - 1
                    line = line.replace(f"{old_n}. **", f"{new_n}. **", 1)

        out.append(line)
        i += 1

    return "\n".join(out) + ("\n" if src_text.endswith("\n") else "")


def main() -> None:
    if len(sys.argv) != 4:
        print("Usage: transform-agents-template.py <src> <dest> <plugin-version>", file=sys.stderr)
        sys.exit(2)

    src = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    version = sys.argv[3]

    content = src.read_text()
    transformed = transform(content)

    # Substitute {{PROJECT_NAME}} placeholder with a neutral default. Consumer
    # apps can edit the title after the overwrite; the plugin doesn't try to
    # guess the consumer's project name at sync time.
    transformed = transformed.replace("{{PROJECT_NAME}}", "Open Mercato App")

    # Prepend versioned marker so the hook can detect "already aligned" vs
    # "needs offer". Place at the very top, above the H1.
    marker = f"<!-- om-superpowers:routing:v{version} -->\n"
    transformed = marker + transformed

    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(transformed)
    print(f"  Wrote {dest} ({len(transformed)} chars, {len(transformed.splitlines())} lines)")


if __name__ == "__main__":
    main()

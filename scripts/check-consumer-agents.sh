#!/usr/bin/env bash
# Check consumer-app AGENTS.md files for dangling .ai/skills/ references.
#
# When the om-superpowers plugin migration consolidated granular OM skills
# (module-scaffold, data-model-design, system-extension, etc.) into references
# under om-implement-spec, the consumer-app AGENTS.md routing tables were left
# pointing at the old `.ai/skills/<name>/SKILL.md` paths. Result: agents read
# AGENTS.md, try to Read a missing file, silently fall back to bare-Claude-Code
# defaults, and never invoke any skill (so they never get subagent guidance,
# upstream-bug routing, etc.).
#
# This script lints one or more consumer-app paths. For each, it:
#   1. Reads <path>/AGENTS.md (and CLAUDE.md if it imports AGENTS.md)
#   2. Extracts every `.ai/skills/<name>/SKILL.md` reference
#   3. Resolves each reference against <path>/.ai/skills/
#   4. Reports dangling refs and a suggested plugin-skill replacement
#
# Usage:
#   scripts/check-consumer-agents.sh <consumer-app-path> [<consumer-app-path>...]
#
# Exit codes:
#   0  all references resolve (or no AGENTS.md found)
#   1  one or more dangling references in any consumer
#   2  invalid arguments

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <consumer-app-path> [<consumer-app-path>...]" >&2
  echo "  Each <consumer-app-path> should contain an AGENTS.md or CLAUDE.md." >&2
  exit 2
fi

# Plugin-skill replacements for the granular OM skills that moved.
# Format: <old-skill-name>|<replacement-instruction>
read -r -d '' REPLACEMENTS <<'EOF' || true
module-scaffold|invoke om-superpowers:om-implement-spec (router → module-scaffold reference)
data-model-design|invoke om-superpowers:om-implement-spec (router → data-model-design reference)
backend-ui-design|invoke om-superpowers:om-ds-guardian
integration-builder|invoke om-superpowers:om-implement-spec (router → integration-builder reference)
system-extension|invoke om-superpowers:om-implement-spec (router → system-extension reference)
eject-and-customize|invoke om-superpowers:om-implement-spec (router → system-extension/eject.md)
troubleshooter|invoke om-superpowers:om-troubleshooter
code-review|invoke om-superpowers:om-code-review
spec-writing|invoke om-superpowers:om-cto (router → spec-writing)
implement-spec|invoke om-superpowers:om-implement-spec
integration-tests|invoke om-superpowers:om-integration-tests
EOF

suggest_replacement() {
  local skill_name="$1"
  while IFS='|' read -r name replacement; do
    [ -z "$name" ] && continue
    if [ "$name" = "$skill_name" ]; then
      echo "$replacement"
      return 0
    fi
  done <<< "$REPLACEMENTS"
  echo "no known plugin replacement — verify manually"
}

total_consumers=0
total_dangling=0
exit_code=0

for consumer_path in "$@"; do
  total_consumers=$((total_consumers + 1))
  consumer_path="${consumer_path%/}"  # strip trailing slash

  if [ ! -d "$consumer_path" ]; then
    echo "ERROR: $consumer_path is not a directory" >&2
    exit_code=1
    continue
  fi

  agents_md="${consumer_path}/AGENTS.md"
  claude_md="${consumer_path}/CLAUDE.md"

  # If CLAUDE.md exists and imports AGENTS.md (via @AGENTS.md), use AGENTS.md.
  # Otherwise check both files.
  files_to_scan=()
  [ -f "$agents_md" ] && files_to_scan+=("$agents_md")
  [ -f "$claude_md" ] && files_to_scan+=("$claude_md")

  if [ ${#files_to_scan[@]} -eq 0 ]; then
    echo "[$consumer_path] no AGENTS.md or CLAUDE.md found — skipping"
    continue
  fi

  echo "=== $consumer_path ==="

  # Extract unique .ai/skills/<name>/SKILL.md references across all scanned files
  refs=$(grep -hoE '\.ai/skills/[a-z0-9_-]+/SKILL\.md' "${files_to_scan[@]}" 2>/dev/null | sort -u || true)

  if [ -z "$refs" ]; then
    echo "  OK: no .ai/skills/ references found"
    continue
  fi

  consumer_dangling=0
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    skill_name=$(echo "$ref" | sed -E 's|\.ai/skills/([a-z0-9_-]+)/SKILL\.md|\1|')
    target="${consumer_path}/${ref}"
    if [ -f "$target" ]; then
      echo "  OK:       $ref"
    else
      consumer_dangling=$((consumer_dangling + 1))
      total_dangling=$((total_dangling + 1))
      replacement=$(suggest_replacement "$skill_name")
      echo "  DANGLING: $ref"
      echo "            → $replacement"
    fi
  done <<< "$refs"

  if [ $consumer_dangling -gt 0 ]; then
    echo "  $consumer_dangling dangling reference(s) in $consumer_path"
    exit_code=1
  fi
done

echo
echo "=== Summary ==="
echo "Consumers checked: $total_consumers"
echo "Dangling references total: $total_dangling"

if [ $exit_code -eq 0 ]; then
  echo "All references resolve."
else
  echo "Found dangling references — agents reading these AGENTS.md files will silently fall back to bare-Claude-Code defaults and skip skill invocation."
fi

exit $exit_code

#!/usr/bin/env bash
# Sync OM platform skills + AGENTS.md files from open-mercato/open-mercato repo (develop branch)
# Run this before each plugin release to update vendored skills and platform references.

set -euo pipefail

REPO="open-mercato/open-mercato"
BRANCH="develop"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/.ai/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_DIR="${PLUGIN_ROOT}/skills"

# Skills to sync: local-name:remote-name pairs
SKILL_PAIRS=(
  "om-code-review:code-review"
  "om-implement-spec:implement-spec"
  "om-spec-writing:spec-writing"
  "om-pre-implement-spec:pre-implement-spec"
  "om-integration-tests:integration-tests"
  "om-integration-builder:integration-builder"
  "om-backend-ui-design:backend-ui-design"
)

# Get current commit SHA for version tracking
echo "Fetching latest commit SHA from ${REPO}@${BRANCH}..."
COMMIT_SHA=$(gh api "repos/${REPO}/commits/${BRANCH}" --jq '.sha' 2>/dev/null || echo "unknown")
echo "Source: ${REPO}@${COMMIT_SHA:0:7}"
echo ""

fetch_file() {
  local url="$1"
  local dest="$2"
  local http_code

  mkdir -p "$(dirname "$dest")"
  http_code=$(curl -sL -w "%{http_code}" -o "$dest" "$url")

  if [ "$http_code" != "200" ]; then
    echo "  WARN: HTTP ${http_code} for $(basename "$dest") — skipping"
    rm -f "$dest"
    return 1
  fi
  return 0
}

for pair in "${SKILL_PAIRS[@]}"; do
  local_name="${pair%%:*}"
  remote_name="${pair##*:}"
  dest_dir="${SKILLS_DIR}/${local_name}"

  echo "Syncing ${local_name} ← ${remote_name}..."

  # Fetch SKILL.md
  fetch_file "${BASE_URL}/${remote_name}/SKILL.md" "${dest_dir}/SKILL.md" || continue

  # Rename skill name field to om-prefixed version
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^name: ${remote_name}$/name: ${local_name}/" "${dest_dir}/SKILL.md"
  else
    sed -i "s/^name: ${remote_name}$/name: ${local_name}/" "${dest_dir}/SKILL.md"
  fi

  # Fetch references/ directory via GitHub API
  refs_json=$(gh api "repos/${REPO}/contents/.ai/skills/${remote_name}/references" 2>/dev/null || echo "[]")

  if [ "$refs_json" != "[]" ] && echo "$refs_json" | jq -e '.[0].name' &>/dev/null; then
    mkdir -p "${dest_dir}/references"
    echo "$refs_json" | jq -r '.[].name' | while read -r ref_file; do
      echo "  + references/${ref_file}"
      fetch_file "${BASE_URL}/${remote_name}/references/${ref_file}" "${dest_dir}/references/${ref_file}"
    done
  fi

  echo ""
done

# Save version info for skills
echo "${COMMIT_SHA}" > "${SKILLS_DIR}/.om-sync-version"
echo "Skills sync complete."
echo ""

# =====================================================================
# Section 2: Sync AGENTS.md files from OM repo
# =====================================================================

AGENTS_BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
AGENTS_DIR="${PLUGIN_ROOT}/om-reference"

# All AGENTS.md paths to vendor (relative to repo root)
AGENTS_PATHS=(
  # Root
  "AGENTS.md"
  # Packages
  "packages/ai-assistant/AGENTS.md"
  "packages/cache/AGENTS.md"
  "packages/cli/AGENTS.md"
  "packages/content/AGENTS.md"
  "packages/core/AGENTS.md"
  "packages/create-app/AGENTS.md"
  "packages/create-app/template/AGENTS.md"
  "packages/enterprise/AGENTS.md"
  "packages/events/AGENTS.md"
  "packages/onboarding/AGENTS.md"
  "packages/queue/AGENTS.md"
  "packages/search/AGENTS.md"
  "packages/shared/AGENTS.md"
  "packages/ui/AGENTS.md"
  "packages/ui/src/backend/AGENTS.md"
  # Core modules
  "packages/core/src/modules/auth/AGENTS.md"
  "packages/core/src/modules/catalog/AGENTS.md"
  "packages/core/src/modules/currencies/AGENTS.md"
  "packages/core/src/modules/customer_accounts/AGENTS.md"
  "packages/core/src/modules/customers/AGENTS.md"
  "packages/core/src/modules/data_sync/AGENTS.md"
  "packages/core/src/modules/integrations/AGENTS.md"
  "packages/core/src/modules/sales/AGENTS.md"
  "packages/core/src/modules/workflows/AGENTS.md"
)

echo "Syncing AGENTS.md files → om-reference/..."
echo ""

agents_ok=0
agents_fail=0

for rel_path in "${AGENTS_PATHS[@]}"; do
  dest="${AGENTS_DIR}/${rel_path}"
  url="${AGENTS_BASE_URL}/${rel_path}"

  echo "  Fetching ${rel_path}..."
  if fetch_file "$url" "$dest"; then
    agents_ok=$((agents_ok + 1))
  else
    agents_fail=$((agents_fail + 1))
  fi
done

echo ""
echo "AGENTS.md sync: ${agents_ok} fetched, ${agents_fail} failed (of ${#AGENTS_PATHS[@]} total)"
echo ""

# Save version info for om-reference
echo "${COMMIT_SHA}" > "${AGENTS_DIR}/.om-sync-version"

# =====================================================================
# Section 3: Referenced docs (specs, contracts)
# =====================================================================

echo "=== Syncing referenced docs ==="

DOCS=(
  "BACKWARD_COMPATIBILITY.md"
  ".ai/specs/SPEC-013-2026-01-27-decouple-module-setup.md"
  ".ai/specs/SPEC-045b-data-sync-hub.md"
  ".ai/specs/SPEC-045-2026-02-24-integration-marketplace.md"
  ".ai/specs/SPEC-045a-foundation.md"
)

REPO_RAW_URL="${AGENTS_BASE_URL}"
REF_DIR="${AGENTS_DIR}"

for doc_path in "${DOCS[@]}"; do
  echo "Fetching ${doc_path}..."
  fetch_file "${REPO_RAW_URL}/${doc_path}" "${REF_DIR}/${doc_path}" || echo "  (skipped)"
done
echo ""

echo "Done. Source commit: ${COMMIT_SHA:0:7}"
echo ""
echo "Next steps:"
echo "  git diff skills/ om-reference/"
echo "  git add skills/ om-reference/"
echo "  git commit -m \"chore: sync OM skills + references from ${REPO}@${COMMIT_SHA:0:7}\""

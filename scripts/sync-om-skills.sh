#!/usr/bin/env bash
# Sync OM platform skills + AGENTS.md files from open-mercato/open-mercato repo (develop branch)
# Run this before each plugin release to update vendored skills and platform references.
#
# Skills are synced from two sources within the OM repo:
#   1. .ai/skills/ — OM core skills (source of truth for skills that exist there)
#   2. packages/create-app/agentic/shared/ai/skills/ — app-building skills only in create-app
#
# Synced skills keep the om- prefix for plugin namespacing but their content comes from upstream.
# om-superpowers unique skills (om-cto, om-product-manager, om-ux, om-user-proxy, om-toolkit-review)
# are NOT synced — they are maintained in this repo.

set -euo pipefail

REPO="open-mercato/open-mercato"
BRANCH="develop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_DIR="${PLUGIN_ROOT}/skills"

CORE_SKILLS_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/.ai/skills"
APP_SKILLS_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/packages/create-app/agentic/shared/ai/skills"

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

sync_skill() {
  local local_name="$1"
  local remote_name="$2"
  local base_url="$3"
  local api_path="$4"
  local dest_dir="${SKILLS_DIR}/${local_name}"

  echo "Syncing ${local_name} ← ${remote_name}..."

  # Fetch SKILL.md
  fetch_file "${base_url}/${remote_name}/SKILL.md" "${dest_dir}/SKILL.md" || return 1

  # Rename skill name field to om-prefixed version
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^name: ${remote_name}$/name: ${local_name}/" "${dest_dir}/SKILL.md"
  else
    sed -i "s/^name: ${remote_name}$/name: ${local_name}/" "${dest_dir}/SKILL.md"
  fi

  # Fetch references/ directory via GitHub API
  refs_json=$(gh api "repos/${REPO}/contents/${api_path}/${remote_name}/references?ref=${BRANCH}" 2>/dev/null || echo "[]")

  if [ "$refs_json" != "[]" ] && echo "$refs_json" | jq -e '.[0].name' &>/dev/null; then
    mkdir -p "${dest_dir}/references"
    echo "$refs_json" | jq -r '.[].name' | while read -r ref_file; do
      echo "  + references/${ref_file}"
      fetch_file "${base_url}/${remote_name}/references/${ref_file}" "${dest_dir}/references/${ref_file}"
    done
  fi

  echo ""
}

# =====================================================================
# Section 1: Sync skills from OM core .ai/skills/ (source of truth)
# =====================================================================

echo "=== Syncing from .ai/skills/ (OM core) ==="
echo ""

# Skills that exist in OM core .ai/skills/
# Format: local-name:remote-name
CORE_SKILL_PAIRS=(
  # Base skills that Piotr dispatches via dispatch context
  "om-implement-spec:implement-spec"
  "om-code-review:code-review"
  "om-spec-writing:spec-writing"
  "om-pre-implement-spec:pre-implement-spec"
  # Overlap skills synced as-is
  "om-backend-ui-design:backend-ui-design"
  "om-integration-builder:integration-builder"
  "om-integration-tests:integration-tests"
  # Auto-* skills (execution engine)
  "om-auto-create-pr:auto-create-pr"
  "om-auto-continue-pr:auto-continue-pr"
  "om-auto-review-pr:auto-review-pr"
)

for pair in "${CORE_SKILL_PAIRS[@]}"; do
  local_name="${pair%%:*}"
  remote_name="${pair##*:}"
  sync_skill "$local_name" "$remote_name" "$CORE_SKILLS_URL" ".ai/skills"
done

# =====================================================================
# Section 2: Sync skills from create-app agentic (app-building skills)
# =====================================================================

echo "=== Syncing from create-app/agentic/ (app skills) ==="
echo ""

# Skills that only exist in create-mercato-app, not in .ai/skills/
APP_SKILL_PAIRS=(
  "om-data-model-design:data-model-design"
  "om-eject-and-customize:eject-and-customize"
  "om-module-scaffold:module-scaffold"
  "om-system-extension:system-extension"
  "om-troubleshooter:troubleshooter"
)

for pair in "${APP_SKILL_PAIRS[@]}"; do
  local_name="${pair%%:*}"
  remote_name="${pair##*:}"
  sync_skill "$local_name" "$remote_name" "$APP_SKILLS_URL" "packages/create-app/agentic/shared/ai/skills"
done

# Save version info for skills
echo "${COMMIT_SHA}" > "${SKILLS_DIR}/.om-sync-version"
echo "Skills sync complete."
echo ""

# =====================================================================
# Section 3: Sync AGENTS.md files from OM repo
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

echo "=== Syncing AGENTS.md files → om-reference/ ==="
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
# Section 4: Referenced docs (specs, contracts)
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
echo "  git commit -m \"chore: sync OM skills + references from ${REPO}@\${COMMIT_SHA:0:7}\""

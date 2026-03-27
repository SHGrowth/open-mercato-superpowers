#!/usr/bin/env bash
# Sync OM platform skills from open-mercato/open-mercato repo (develop branch)
# Run this before each plugin release to update vendored skills.

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

# Save version info
echo "${COMMIT_SHA}" > "${SKILLS_DIR}/.om-sync-version"
echo "Done. Source commit: ${COMMIT_SHA:0:7}"
echo ""
echo "Next steps:"
echo "  git diff skills/"
echo "  git add skills/"
echo "  git commit -m \"chore: sync OM skills from ${REPO}@${COMMIT_SHA:0:7}\""

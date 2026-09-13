#!/usr/bin/env bash
# Validates every skill in skills/ has a well-formed SKILL.md
# Run from repo root: ./scripts/validate.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
EXIT_CODE=0

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "❌ No skills/ directory found"
  exit 1
fi

for skill_path in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_path")"
  skill_md="$skill_path/SKILL.md"

  echo "Checking $skill_name..."

  # 1. SKILL.md exists
  if [[ ! -f "$skill_md" ]]; then
    echo "  ❌ Missing SKILL.md"
    EXIT_CODE=1
    continue
  fi

  # 2. Has YAML frontmatter (starts with ---)
  if ! head -n 1 "$skill_md" | grep -q '^---$'; then
    echo "  ❌ SKILL.md doesn't start with YAML frontmatter (---)"
    EXIT_CODE=1
    continue
  fi

  # 3. Frontmatter is closed before the body. A missing closing delimiter used
  # to make the remaining document look like frontmatter and pass validation.
  frontmatter_end=$(awk 'NR > 1 && /^---$/{print NR; exit}' "$skill_md")
  if [[ -z "$frontmatter_end" ]]; then
    echo "  ❌ Frontmatter is missing its closing delimiter"
    EXIT_CODE=1
    continue
  fi

  # 4. Has a name field in frontmatter
  if ! awk '/^---$/{c++; next} c==1' "$skill_md" | grep -q '^name:'; then
    echo "  ❌ Frontmatter missing 'name' field"
    EXIT_CODE=1
    continue
  fi

  # 5. name field matches folder name
  declared_name=$(awk '/^---$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_md")
  if [[ "$declared_name" != "$skill_name" ]]; then
    echo "  ❌ Frontmatter name '$declared_name' doesn't match folder name '$skill_name'"
    EXIT_CODE=1
    continue
  fi

  # 6. Has a description field
  if ! awk '/^---$/{c++; next} c==1' "$skill_md" | grep -q '^description:'; then
    echo "  ❌ Frontmatter missing 'description' field"
    EXIT_CODE=1
    continue
  fi

  # 7. Description is at least 50 chars (catches lazy descriptions)
  desc_length=$(awk '/^---$/{c++; next} c==1 && /^description:/{sub(/^description:[[:space:]]*/, ""); print length; exit}' "$skill_md")
  if [[ "$desc_length" -lt 50 ]]; then
    echo "  ⚠️  Description is short ($desc_length chars). Make it more 'pushy' — explicit trigger contexts."
  fi

  echo "  ✅ OK"
done

echo
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "All skills valid."
else
  echo "❌ Validation failed."
fi

exit $EXIT_CODE

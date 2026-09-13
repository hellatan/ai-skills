#!/usr/bin/env bash
# Validates every skill in skills/ has a well-formed SKILL.md
# Run from repo root: ./scripts/validate.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
EXIT_CODE=0

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "❌ PyYAML is required; install development dependencies with: python3 -m pip install -r requirements-dev.txt" >&2
  exit 1
fi

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

  # 3. Parse the bounded YAML document, rather than treating delimiter and
  # field-shaped lines as YAML. PyYAML is declared in requirements-dev.txt.
  if ! parsed_fields=$(python3 - "$skill_md" 2>&1 <<'PY'
import sys
import yaml

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()
try:
    end = lines.index("---", 1)
except ValueError:
    raise SystemExit("frontmatter is missing its closing delimiter")
try:
    data = yaml.safe_load("\n".join(lines[1:end]))
except yaml.YAMLError as exc:
    raise SystemExit(f"invalid YAML frontmatter: {exc}")
if not isinstance(data, dict):
    raise SystemExit("frontmatter must be a YAML mapping")
name = data.get("name")
description = data.get("description")
if not isinstance(name, str) or not name:
    raise SystemExit("frontmatter missing string 'name' field")
if not isinstance(description, str) or not description:
    raise SystemExit("frontmatter missing string 'description' field")
print(name)
print(len(description))
PY
)
  then
    echo "  ❌ $parsed_fields"
    EXIT_CODE=1
    continue
  fi

  declared_name=$(printf '%s\n' "$parsed_fields" | sed -n '1p')
  desc_length=$(printf '%s\n' "$parsed_fields" | sed -n '2p')
  if [[ "$declared_name" != "$skill_name" ]]; then
    echo "  ❌ Frontmatter name '$declared_name' doesn't match folder name '$skill_name'"
    EXIT_CODE=1
    continue
  fi

  # 4. Description is at least 50 chars (catches lazy descriptions)
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

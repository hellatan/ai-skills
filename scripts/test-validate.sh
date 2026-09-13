#!/usr/bin/env bash
# Regression test for the required closing YAML-frontmatter delimiter.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d /private/tmp/ai-skills-validate-test.XXXXXX)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/scripts" "$fixture/repo/skills/broken"
printf '%s\n' '---' 'name: broken' 'description: enough description to pass the length warning when parsed' '# no closing delimiter' > "$fixture/repo/skills/broken/SKILL.md"
cp "$repo_root/scripts/validate.sh" "$fixture/repo/scripts/validate.sh"
if "$fixture/repo/scripts/validate.sh" 2>/dev/null; then
  echo "validator accepted missing closing frontmatter delimiter" >&2
  exit 1
fi
echo "validator failure fixture passed"

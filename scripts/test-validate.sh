#!/usr/bin/env bash
# Regression tests for malformed YAML frontmatter.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/ai-skills-validate-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo/scripts"
cp "$repo_root/scripts/validate.sh" "$fixture/repo/scripts/validate.sh"

assert_invalid() {
  local fixture_name="$1"
  shift
  mkdir -p "$fixture/repo/skills/$fixture_name"
  printf '%s\n' "$@" > "$fixture/repo/skills/$fixture_name/SKILL.md"
  if "$fixture/repo/scripts/validate.sh" >/dev/null 2>&1; then
    echo "validator accepted invalid $fixture_name frontmatter" >&2
    exit 1
  fi
  rm -rf "$fixture/repo/skills/$fixture_name"
}

assert_invalid missing-delimiter \
  '---' 'name: missing-delimiter' \
  'description: enough description to pass the length warning when parsed' \
  '# no closing delimiter'
assert_invalid invalid-yaml \
  '---' 'name: invalid-yaml' 'description: [unterminated' '---'
echo "validator malformed-frontmatter fixtures passed"

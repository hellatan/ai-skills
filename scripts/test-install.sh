#!/usr/bin/env bash
# Isolated installer regression fixtures. Never writes a real discovery root.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d /private/tmp/ai-skills-install-test.XXXXXX)"
trap 'rm -rf "$fixture"' EXIT
git clone -q --no-hardlinks "$repo_root" "$fixture/repo"
cp "$repo_root/scripts/install.sh" "$fixture/repo/scripts/install.sh"
chmod +x "$fixture/repo/scripts/install.sh"
mkdir -p "$fixture/claude skills" "$fixture/agents skills"

# agents-only selection, repeat invocation, and a foreign dangling collision.
ln -s /foreign/missing "$fixture/agents skills/foreign"
SKILLS_CLAUDE_DIR="$fixture/claude skills" \
SKILLS_AGENTS_DIR="$fixture/agents skills" \
  "$fixture/repo/scripts/install.sh" --agents --quiet
test -L "$fixture/agents skills/project-scaffold"
test -L "$fixture/agents skills/foreign"
test ! -e "$fixture/claude skills/project-scaffold"
SKILLS_CLAUDE_DIR="$fixture/claude skills" \
SKILLS_AGENTS_DIR="$fixture/agents skills" \
  "$fixture/repo/scripts/install.sh" --quiet
test -L "$fixture/agents skills/project-scaffold"

# Both destinations install, while an exact-prefix lookalike remains foreign.
ln -s "$fixture/repo/skills-not/project-scaffold" "$fixture/agents skills/lookalike"
SKILLS_CLAUDE_DIR="$fixture/claude skills" \
SKILLS_AGENTS_DIR="$fixture/agents skills" \
  "$fixture/repo/scripts/install.sh" --both --quiet
test -L "$fixture/claude skills/project-scaffold"
test -L "$fixture/agents skills/lookalike"

# An owned stale relative link is pruned without touching foreign links.
ln -s "$fixture/repo/skills/missing-skill" "$fixture/agents skills/missing-skill"
SKILLS_CLAUDE_DIR="$fixture/claude skills" \
SKILLS_AGENTS_DIR="$fixture/agents skills" \
  "$fixture/repo/scripts/install.sh" --agents --quiet
test ! -L "$fixture/agents skills/missing-skill"
echo "installer fixtures passed"

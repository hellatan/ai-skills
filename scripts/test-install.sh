#!/usr/bin/env bash
# Isolated installer regression fixtures. Never writes a real discovery root.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/ai-skills-install-test.XXXXXX")"
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

# A source archive has no Git metadata but still installs selected roots.
mkdir -p "$fixture/archive/scripts"
cp -R "$fixture/repo/skills" "$fixture/archive/skills"
cp "$repo_root/scripts/install.sh" "$fixture/archive/scripts/install.sh"
chmod +x "$fixture/archive/scripts/install.sh"
SKILLS_CLAUDE_DIR="$fixture/archive claude" \
SKILLS_AGENTS_DIR="$fixture/archive agents" \
  "$fixture/archive/scripts/install.sh" --both --quiet
test -L "$fixture/archive claude/project-scaffold"
test -L "$fixture/archive agents/project-scaffold"

# Linked worktrees refuse installation before any selected root is created.
git -C "$fixture/repo" worktree add -q -b fixture-linked "$fixture/linked"
cp "$repo_root/scripts/install.sh" "$fixture/linked/scripts/install.sh"
chmod +x "$fixture/linked/scripts/install.sh"
SKILLS_CLAUDE_DIR="$fixture/worktree claude" \
SKILLS_AGENTS_DIR="$fixture/worktree agents" \
  "$fixture/linked/scripts/install.sh" --both --quiet
test ! -e "$fixture/worktree claude/project-scaffold"
test ! -e "$fixture/worktree agents/project-scaffold"
git -C "$fixture/repo" worktree remove --force "$fixture/linked"

# An explicitly requested custom hooks path still preserves a foreign hook.
mkdir -p "$fixture/shared hooks"
printf '%s\n' foreign-hook > "$fixture/shared hooks/post-merge"
git -C "$fixture/repo" config core.hooksPath "$fixture/shared hooks"
SKILLS_CLAUDE_DIR="$fixture/claude skills" \
SKILLS_AGENTS_DIR="$fixture/agents skills" \
  "$fixture/repo/scripts/install.sh" --agents --install-hooks --quiet
test "$(cat "$fixture/shared hooks/post-merge")" = foreign-hook
echo "installer fixtures passed"

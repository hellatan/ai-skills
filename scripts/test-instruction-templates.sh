#!/usr/bin/env bash
# Contract checks for authored instruction templates; no project is generated.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
templates="$root/skills/claude-md-init/references/templates.md"
scaffold="$root/skills/project-scaffold/references/configs/nextjs.md"

grep -Fq 'Generate it as' "$templates"
grep -Fq '`AGENTS.md`' "$templates"
grep -Fq 'thin `CLAUDE.md` adapter' "$templates"
grep -Fq 'docs/development/git-workflow.md' "$templates"
grep -Fq 'Living doc:' "$templates"
! grep -Fq '@.claude/rules/git-workflow.md' "$templates"
grep -Fq 'Preserve AGENTS.md and CLAUDE.md' "$scaffold"
! grep -Fq 'rm -rf .git AGENTS.md CLAUDE.md' "$scaffold"
echo "instruction-template fixtures passed"

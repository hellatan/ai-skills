#!/usr/bin/env bash
# Exercise representative instruction-template extraction and generated-file
# preservation rules in disposable project fixtures.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
templates="$root/skills/claude-md-init/references/templates.md"
nextjs="$root/skills/project-scaffold/references/configs/nextjs.md"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/ai-skills-instructions-test.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

extract_template() {
  local heading="$1" output="$2"
  awk -v heading="$heading" '
    $0 == heading { found=1; next }
    found && /^```markdown$/ { in_fence=1; next }
    in_fence && /^```$/ { exit }
    in_fence { print }
  ' "$templates" > "$output"
  test -s "$output"
}

extract_bash_block() {
  local needle="$1" output="$2"
  awk -v needle="$needle" '
    index($0, needle) { found=1 }
    found && /^[[:space:]]*```bash$/ { in_fence=1; next }
    in_fence && /^[[:space:]]*```$/ { exit }
    in_fence { print }
  ' "$nextjs" > "$output"
  test -s "$output"
}

# Generate a representative root instruction file from the canonical preamble,
# then add its thin compatibility adapter. Nested authored files are preserved.
project="$fixture/root-project"
mkdir -p "$project/frontend" "$project/docs/development"
extract_template '## Universal preamble (always include)' "$project/AGENTS.md"
sed -i.bak -e 's/<PROJECT_NAME>/Fixture project/' \
  -e 's/<One-line description of what this repo is and what stack.>/Generated fixture./' \
  "$project/AGENTS.md"
rm "$project/AGENTS.md.bak"
cat > "$project/CLAUDE.md" <<'EOF'
# Claude adapter

Read and follow [AGENTS.md](AGENTS.md). It is the canonical project instruction file.
EOF
printf '%s\n' 'authored nested AGENTS sentinel' > "$project/frontend/AGENTS.md"
printf '%s\n' 'authored nested CLAUDE sentinel' > "$project/frontend/CLAUDE.md"
printf '%s\n' '# Git workflow' > "$project/docs/development/git-workflow.md"
grep -Fq 'docs/development/git-workflow.md' "$project/AGENTS.md"
grep -Fq 'npm run check:all' "$project/AGENTS.md"
grep -Fq 'thin `CLAUDE.md` adapter' "$templates"
grep -Fq 'canonical project instruction file' "$project/CLAUDE.md"
grep -Fxq 'authored nested AGENTS sentinel' "$project/frontend/AGENTS.md"
grep -Fxq 'authored nested CLAUDE sentinel' "$project/frontend/CLAUDE.md"

# Stack templates retain their own runnable guidance.
extract_template '## Backend — Python (FastAPI)' "$fixture/python-AGENTS.md"
grep -Fq 'python scripts/dev.py check:all' "$fixture/python-AGENTS.md"
! grep -Fq 'npm run check:all' "$fixture/python-AGENTS.md"
extract_template '## Toolbox / scripts repo (no manifest)' "$fixture/toolbox-AGENTS.md"
grep -Fq '## How work ships' "$fixture/toolbox-AGENTS.md"
! grep -Fq 'npm run check:all' "$fixture/toolbox-AGENTS.md"

# Execute the exact changed cleanup snippets against root and nested generated
# fixtures. They remove only the nested Git directory, preserving instructions.
mkdir -p "$fixture/next-root/.git" "$fixture/next-nested/frontend/.git"
printf '%s\n' root-agents > "$fixture/next-root/AGENTS.md"
printf '%s\n' root-claude > "$fixture/next-root/CLAUDE.md"
printf '%s\n' nested-agents > "$fixture/next-nested/frontend/AGENTS.md"
printf '%s\n' nested-claude > "$fixture/next-nested/frontend/CLAUDE.md"
extract_bash_block 'remove it before the skill' "$fixture/root-cleanup.sh"
extract_bash_block 'For the **subdir** install path' "$fixture/nested-cleanup.sh"
(cd "$fixture/next-root" && bash "$fixture/root-cleanup.sh")
(cd "$fixture/next-nested" && bash "$fixture/nested-cleanup.sh")
test ! -e "$fixture/next-root/.git"
test ! -e "$fixture/next-nested/frontend/.git"
grep -Fxq root-agents "$fixture/next-root/AGENTS.md"
grep -Fxq root-claude "$fixture/next-root/CLAUDE.md"
grep -Fxq nested-agents "$fixture/next-nested/frontend/AGENTS.md"
grep -Fxq nested-claude "$fixture/next-nested/frontend/CLAUDE.md"
echo "instruction-template fixtures passed"

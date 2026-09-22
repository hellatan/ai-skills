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
# Both preamble instructions live in a "## Before working" section: the
# cloud-session contract line first (placeholder only), the workflow read line
# second, after the living-doc note and before "## Lifecycle".
grep -Fq 'shared workflow contract' "$project/AGENTS.md"
grep -Fq '<CONTRACT_REPOS>' "$project/AGENTS.md"
grep -Fxq '## Before working' "$project/AGENTS.md"
grep -q '^- Cloud sessions load the shared workflow contract' "$project/AGENTS.md"
grep -q '^- Read `docs/development/git-workflow.md`' "$project/AGENTS.md"
# Only one living-doc note, and it sits above the section.
test "$(grep -c -F 'Living doc' "$project/AGENTS.md")" -eq 1
test "$(grep -n -F 'Living doc' "$project/AGENTS.md" | head -1 | cut -d: -f1)" -lt \
  "$(grep -n -Fx '## Before working' "$project/AGENTS.md" | head -1 | cut -d: -f1)"
test "$(grep -n -Fx '## Before working' "$project/AGENTS.md" | head -1 | cut -d: -f1)" -lt \
  "$(grep -n -F 'shared workflow contract' "$project/AGENTS.md" | head -1 | cut -d: -f1)"
test "$(grep -n -F 'shared workflow contract' "$project/AGENTS.md" | head -1 | cut -d: -f1)" -lt \
  "$(grep -n -F 'docs/development/git-workflow.md' "$project/AGENTS.md" | head -1 | cut -d: -f1)"
test "$(grep -n -F 'docs/development/git-workflow.md' "$project/AGENTS.md" | head -1 | cut -d: -f1)" -lt \
  "$(grep -n -Fx '## Lifecycle' "$project/AGENTS.md" | head -1 | cut -d: -f1)"
grep -Fq 'npm run check:all' "$project/AGENTS.md"
grep -Fq 'thin `CLAUDE.md` adapter' "$templates"
grep -Fq 'canonical project instruction file' "$project/CLAUDE.md"
grep -Fxq 'authored nested AGENTS sentinel' "$project/frontend/AGENTS.md"
grep -Fxq 'authored nested CLAUDE sentinel' "$project/frontend/CLAUDE.md"

# Stack templates retain their own runnable guidance.
extract_template '## Backend — Python (FastAPI)' "$fixture/python-AGENTS.md"
grep -Fq 'python scripts/dev.py check:all' "$fixture/python-AGENTS.md"
grep -Fxq '## Before working' "$fixture/python-AGENTS.md"
grep -q '^- Cloud sessions load the shared workflow contract' "$fixture/python-AGENTS.md"
! grep -Fq 'npm run check:all' "$fixture/python-AGENTS.md"
extract_template '## Toolbox / scripts repo (no manifest)' "$fixture/toolbox-AGENTS.md"
grep -Fq '## How work ships' "$fixture/toolbox-AGENTS.md"
grep -Fxq '## Before working' "$fixture/toolbox-AGENTS.md"
grep -q '^- Cloud sessions load the shared workflow contract' "$fixture/toolbox-AGENTS.md"
! grep -Fq 'npm run check:all' "$fixture/toolbox-AGENTS.md"

# Pinning the bullet order in the universal preamble alone left a swapped pair
# in any per-stack block green, so check every template block instead: extract
# each ```markdown fence, then assert the shape of every "## Before working"
# section it contains.
blocks="$fixture/blocks"
mkdir -p "$blocks"
awk -v dir="$blocks" '
  !in_fence && /^```markdown$/ { n++; file = sprintf("%s/block-%02d.md", dir, n); in_fence=1; next }
  in_fence && /^```$/ { in_fence=0; next }
  in_fence { print > file }
' "$templates"

section="$fixture/before-working-section.txt"
bullets="$fixture/before-working-bullets.txt"
checked=0
for block in "$blocks"/block-*.md; do
  grep -Fxq '## Before working' "$block" || continue
  checked=$((checked + 1))
  name="$(basename "$block")"
  if test "$(grep -c -Fx '## Before working' "$block")" -ne 1; then
    echo "$name: expected exactly one '## Before working' heading" >&2
    exit 1
  fi
  if test "$(grep -c -F 'Living doc' "$block")" -gt 1; then
    echo "$name: more than one living-doc note" >&2
    exit 1
  fi
  # The section body, tagged line by line and terminated by whichever heading
  # follows it, so both ordering and adjacency stay visible.
  awk '
    $0 == "## Before working" { in_section=1; next }
    in_section && /^## / { print "NEXT:" $0; exit }
    in_section { print "BODY:" $0 }
  ' "$block" > "$section"
  if test "$(tail -n 1 "$section")" != 'NEXT:## Lifecycle'; then
    echo "$name: '## Before working' is not immediately followed by '## Lifecycle'" >&2
    exit 1
  fi
  if grep -qvE '^(BODY:$|BODY:- |BODY:[[:space:]]|NEXT:## Lifecycle$)' "$section"; then
    echo "$name: '## Before working' carries something other than bullets" >&2
    exit 1
  fi
  grep -n '^BODY:- ' "$section" > "$bullets" || true
  if ! head -n 1 "$bullets" | grep -q '^[0-9][0-9]*:BODY:- Cloud sessions load the shared workflow contract'; then
    echo "$name: the cloud-session line is not the first bullet" >&2
    exit 1
  fi
  # Where the block links the workflow document, that line is the bullet
  # immediately after the cloud-session one, with no blank line between them.
  if grep -Fq 'Read `docs/development/git-workflow.md`' "$block"; then
    first_bullet="$(head -n 1 "$bullets" | cut -d: -f1)"
    second_bullet="$(sed -n '2p' "$bullets")"
    if ! printf '%s\n' "$second_bullet" | grep -q '^[0-9][0-9]*:BODY:- Read `docs/development/git-workflow.md`'; then
      echo "$name: the workflow read line is not the second bullet" >&2
      exit 1
    fi
    if test "$(printf '%s\n' "$second_bullet" | cut -d: -f1)" -ne "$((first_bullet + 1))"; then
      echo "$name: a blank line separates the first two bullets" >&2
      exit 1
    fi
  fi
done
if test "$checked" -ne 8; then
  echo "expected 8 template blocks with a '## Before working' section, found $checked" >&2
  exit 1
fi

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

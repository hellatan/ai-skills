#!/usr/bin/env bash
# Install this checkout's skills into an explicitly selected discovery root.
# The default remains Claude-only for backward compatibility.  A selection is
# saved clone-locally so non-blocking Git hooks repeat only that selection.
set -euo pipefail
shopt -s nullglob

QUIET=0
REQUESTED_TARGET=""
FROM_HOOK=0
INSTALL_HOOKS=0
CLAUDE_DIR="${SKILLS_CLAUDE_DIR:-$HOME/.claude/skills}"
AGENTS_DIR="${SKILLS_AGENTS_DIR:-$HOME/.agents/skills}"

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [--target claude|agents|both] [--quiet] [--install-hooks]

Installs symlinks into Claude Code (~/.claude/skills), agent-neutral discovery
(~/.agents/skills), or both. No argument preserves the legacy Claude-only
behavior unless this clone has a previously saved explicit target selection.
Environment variables SKILLS_CLAUDE_DIR and SKILLS_AGENTS_DIR are intended for
isolated tests. --install-hooks is required before modifying a custom or shared
Git hooks directory.
EOF
}
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --target=*) REQUESTED_TARGET="${arg#--target=}" ;;
    --claude) REQUESTED_TARGET="claude" ;;
    --agents) REQUESTED_TARGET="agents" ;;
    --both) REQUESTED_TARGET="both" ;;
    --from-hook) FROM_HOOK=1 ;;
    --install-hooks) INSTALL_HOOKS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done
case "$REQUESTED_TARGET" in ''|claude|agents|both) ;; *) echo "invalid target: $REQUESTED_TARGET" >&2; exit 2;; esac
say() { [[ "$QUIET" -eq 1 ]] || echo "$@"; }
note() { echo "$@"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
HOOKS_SRC="$REPO_ROOT/.githooks"
[[ -d "$SKILLS_DIR" ]] || { echo "No skills/ directory found at $SKILLS_DIR" >&2; exit 1; }

git_dir_abs() {
  local value
  value="$(git -C "$REPO_ROOT" rev-parse "$1" 2>/dev/null || true)"
  [[ -z "$value" ]] && return 0
  [[ "$value" = /* ]] || value="$REPO_ROOT/$value"
  (cd "$value" 2>/dev/null && pwd) || echo "$value"
}
GIT_COMMON="$(git_dir_abs --git-common-dir)"
GIT_LOCAL="$(git_dir_abs --git-dir)"
if [[ -n "$GIT_COMMON" && "$GIT_COMMON" != "$GIT_LOCAL" && "${SKILLS_INSTALL_ALLOW_WORKTREE:-0}" != 1 ]]; then
  [[ "$QUIET" -eq 1 ]] && exit 0
  echo "Skipping: this is a linked worktree. Install from the primary checkout instead."
  exit 0
fi

saved_target="$(git -C "$REPO_ROOT" config --local --get ai-skills.installTarget 2>/dev/null || true)"
if [[ -z "$REQUESTED_TARGET" ]]; then
  REQUESTED_TARGET="${saved_target:-claude}"
fi
if [[ "$FROM_HOOK" -eq 0 ]]; then
  git -C "$REPO_ROOT" config --local ai-skills.installTarget "$REQUESTED_TARGET" 2>/dev/null || true
fi

# Absolute lexical paths let us compare valid, relative, and dangling symlinks
# exactly without treating a prefix lookalike as owned.
absolute_path() {
  python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1"
}
link_points_to() {
  local link="$1" expected="$2" raw resolved
  raw="$(readlink "$link")"
  if [[ "$raw" = /* ]]; then resolved="$(absolute_path "$raw")"; else resolved="$(absolute_path "$(dirname "$link")/$raw")"; fi
  [[ "$resolved" == "$(absolute_path "$expected")" ]]
}
install_root() {
  local target_dir="$1" skill_path skill_name link
  mkdir -p "$target_dir"
  say "Installing skills from $SKILLS_DIR -> $target_dir"
  for skill_path in "$SKILLS_DIR"/*/; do
    skill_name="$(basename "$skill_path")"; link="$target_dir/$skill_name"
    if [[ -L "$link" ]]; then
      if link_points_to "$link" "${skill_path%/}"; then say "  $skill_name: already installed"; continue; fi
      note "WARNING: $link is an unowned symlink; leaving it unchanged."
      continue
    fi
    if [[ -e "$link" ]]; then note "WARNING: $link exists and is not an owned symlink; leaving it unchanged."; continue; fi
    ln -s "${skill_path%/}" "$link"; note "installed $skill_name -> $target_dir"
  done
  for link in "$target_dir"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    # A stale link is owned only when its intended path is directly under this
    # checkout's skills directory; a prefix match is never sufficient.
    local raw candidate parent
    raw="$(readlink "$link")"; parent="$(dirname "$link")"
    [[ "$raw" = /* ]] && candidate="$(absolute_path "$raw")" || candidate="$(absolute_path "$parent/$raw")"
    if [[ "$(dirname "$candidate")" == "$(absolute_path "$SKILLS_DIR")" ]]; then
      rm "$link"; note "pruned owned stale link $(basename "$link")"
    else
      note "WARNING: dangling unowned link $link -> $raw; leaving it unchanged."
    fi
  done
}
case "$REQUESTED_TARGET" in
  claude) install_root "$CLAUDE_DIR" ;;
  agents) install_root "$AGENTS_DIR" ;;
  both) install_root "$CLAUDE_DIR"; install_root "$AGENTS_DIR" ;;
esac

if [[ "$INSTALL_HOOKS" -eq 1 ]]; then
  hooks_dir="$(git -C "$REPO_ROOT" config --get core.hooksPath || true)"
  [[ -n "$hooks_dir" && "$hooks_dir" != /* ]] && hooks_dir="$REPO_ROOT/$hooks_dir"
  if [[ -z "$hooks_dir" && -n "$GIT_COMMON" ]]; then hooks_dir="$GIT_COMMON/hooks"; fi
  if [[ -z "$hooks_dir" ]]; then note "WARNING: not a Git clone; hooks were not installed."; exit 0; fi
  mkdir -p "$hooks_dir"
  for source in "$HOOKS_SRC"/*; do
    dest="$hooks_dir/$(basename "$source")"
    if [[ -L "$dest" ]] && link_points_to "$dest" "$source"; then continue; fi
    if [[ -e "$dest" || -L "$dest" ]]; then note "WARNING: hook collision at $dest; leaving it unchanged."; continue; fi
    ln -s "$source" "$dest"; note "installed hook $(basename "$source")"
  done
elif [[ "$FROM_HOOK" -eq 0 ]]; then
  note "Git hooks were not changed. Re-run with --install-hooks to opt in."
fi

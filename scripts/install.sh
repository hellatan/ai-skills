#!/usr/bin/env bash
# Symlinks each skill into ~/.claude/skills/<skill-name>, prunes links to skills
# this repo no longer has, and installs the git hooks that re-run this script
# after every pull/merge/rebase/branch-switch.
#
# Run from repo root: ./scripts/install.sh [--quiet]
#
#   --quiet   print only changes, warnings, and errors (what the hooks use)
#
# Env escape hatch:
#   SKILLS_INSTALL_ALLOW_WORKTREE=1   allow running from a linked worktree
#                                     (tests only — see the worktree guard below)

set -euo pipefail
shopt -s nullglob

QUIET=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    -h|--help) awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# say() is suppressed by --quiet; note() always prints. Anything a hook run
# surfaces has to be worth interrupting a `git pull` for, so no-ops use say().
say()  { [[ "$QUIET" -eq 1 ]] || echo "$@"; }
note() { echo "$@"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
HOOKS_SRC="$REPO_ROOT/.githooks"
TARGET_DIR="$HOME/.claude/skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "❌ No skills/ directory found at $SKILLS_DIR" >&2
  exit 1
fi

# --- Worktree guard -----------------------------------------------------------
# ~/.claude/skills must point at the primary checkout. A linked worktree is
# throwaway — `git worktree remove` would leave every skill dangling. The hooks
# fire inside worktrees too (worktree add runs post-checkout), so this exits
# silently under --quiet rather than nagging.
# Resolved by hand rather than with `rev-parse --path-format=absolute`, which
# needs git >= 2.31. Empty means "not a git clone" — every caller checks.
git_dir_abs() {
  local d
  d="$(git -C "$REPO_ROOT" rev-parse "$1" 2>/dev/null || true)"
  [[ -z "$d" ]] && return 0
  [[ "$d" != /* ]] && d="$REPO_ROOT/$d"
  (cd "$d" 2>/dev/null && pwd) || echo "$d"
}
GIT_COMMON="$(git_dir_abs --git-common-dir)"
GIT_LOCAL="$(git_dir_abs --git-dir)"
if [[ -n "$GIT_COMMON" && "$GIT_COMMON" != "$GIT_LOCAL" && "${SKILLS_INSTALL_ALLOW_WORKTREE:-0}" != "1" ]]; then
  [[ "$QUIET" -eq 1 ]] && exit 0
  primary="$(dirname "$GIT_COMMON")"
  echo "⏭️  Skipping: this is a linked worktree, not the primary checkout."
  echo "    Symlinking skills here would break them when the worktree is removed."
  echo "    Install from the primary checkout instead:"
  echo "      cd '$primary' && ./scripts/install.sh"
  exit 0
fi

mkdir -p "$TARGET_DIR"
say "Installing skills from $SKILLS_DIR → $TARGET_DIR"
say

# --- Skills -------------------------------------------------------------------
for skill_path in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_path")"
  target="$TARGET_DIR/$skill_name"

  # If target exists and isn't a symlink to our repo, warn
  if [[ -e "$target" && ! -L "$target" ]]; then
    note "⚠️  $skill_name: $target exists and is not a symlink. Skipping."
    note "    To replace with this repo's version: rm -rf '$target' && rerun this script."
    continue
  fi

  # If symlink exists pointing elsewhere, replace it
  if [[ -L "$target" ]]; then
    current_target="$(readlink "$target")"
    if [[ "$current_target" == "$skill_path"* ]] || [[ "$current_target" == "${skill_path%/}" ]]; then
      say "✅ $skill_name: already symlinked correctly"
      continue
    fi
    note "🔄 $skill_name: replacing existing symlink"
    rm "$target"
  fi

  ln -s "${skill_path%/}" "$target"
  note "✅ $skill_name: installed"
done

# --- Prune --------------------------------------------------------------------
# A renamed or deleted skill leaves a dangling symlink behind that Claude Code
# still tries to load. Only links pointing into THIS repo's skills/ are ours to
# remove — links to other repos (e.g. pinky-log) are reported, never touched.
for link in "$TARGET_DIR"/*; do
  [[ -L "$link" ]] || continue
  [[ -e "$link" ]] && continue
  link_name="$(basename "$link")"
  link_target="$(readlink "$link")"
  if [[ "$link_target" == "$SKILLS_DIR"/* ]]; then
    rm "$link"
    note "🧹 $link_name: pruned (no longer in this repo)"
  else
    note "⚠️  $link_name: dangling symlink → $link_target"
    note "    Not from this repo, so leaving it. Remove with: rm '$link'"
  fi
done

# --- Git hooks ----------------------------------------------------------------
# Symlinked into whatever hooks dir this clone actually uses, so an existing
# core.hooksPath keeps working instead of being overwritten.
hooks_dir="$(git -C "$REPO_ROOT" config --get core.hooksPath || true)"
if [[ -z "$hooks_dir" && -n "$GIT_COMMON" ]]; then
  hooks_dir="$GIT_COMMON/hooks"
fi
# A relative core.hooksPath resolves against the working-tree root.
[[ -n "$hooks_dir" && "$hooks_dir" != /* ]] && hooks_dir="$REPO_ROOT/$hooks_dir"

if [[ -d "$HOOKS_SRC" && -z "$hooks_dir" ]]; then
  # Source tarball rather than a clone, or no git on PATH. The skills above are
  # installed and usable; only the auto-sync is unavailable.
  note "⚠️  git hooks not installed: $REPO_ROOT is not a git clone."
  note "    Skills are linked, but they won't re-sync on their own. Re-run this"
  note "    script by hand after updating, or clone the repo instead."
elif [[ -d "$HOOKS_SRC" ]]; then
  mkdir -p "$hooks_dir"
  for hook_src in "$HOOKS_SRC"/*; do
    hook_name="$(basename "$hook_src")"
    dest="$hooks_dir/$hook_name"

    if [[ -L "$dest" && "$(readlink "$dest")" == "$hook_src" ]]; then
      say "✅ hook $hook_name: already installed"
      continue
    fi
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      note "⚠️  hook $hook_name: $dest exists and is not a symlink. Skipping."
      note "    To replace with this repo's version: rm '$dest' && rerun this script."
      continue
    fi
    [[ -L "$dest" ]] && rm "$dest"
    ln -s "$hook_src" "$dest"
    note "✅ hook $hook_name: installed"
  done
fi

say
say "Done. Run 'ls -la $TARGET_DIR' to verify."

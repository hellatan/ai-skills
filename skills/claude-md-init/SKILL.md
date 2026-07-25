---
name: claude-md-init
description: Add a CLAUDE.md to an existing repo — detects the project's stack from `package.json` / `pyproject.toml` / framework deps, picks the matching template (Next.js, FastAPI, Fastify, fullstack variants, library, research notebooks, manifest-less toolbox/scripts repos), and writes a lean 50-120 line CLAUDE.md scoped to project identity, canonical commands, and non-obvious gotchas. Use when the user wants to "add CLAUDE.md", "scaffold a CLAUDE.md", "set up Claude Code config", or otherwise bring a CLAUDE.md to a repo that doesn't have one. Refuses to overwrite an existing CLAUDE.md without consent.
---

# claude-md-init

Adds a CLAUDE.md to an existing repo, picking the right per-stack template. Scoped to **project identity, canonical commands, and non-obvious gotchas** — leans on the user's global `~/.claude/CLAUDE.md` for git workflow, link formatting, etc., so the per-repo file stays at 50–120 lines.

## When to trigger

User says any of:
- "add CLAUDE.md / a CLAUDE.md"
- "scaffold a CLAUDE.md"
- "set up Claude Code config for this repo"
- "init a CLAUDE.md"

## When NOT to use

- Repo already has a CLAUDE.md and the user wants to *edit* it — open the file directly, don't run this skill.
- Brand-new project — `project-scaffold` calls this skill internally for Step 10.

## What this skill does NOT include

- **Git workflow rules** (branching, committing, push refspecs) — those live in the user's global CLAUDE.md.
- **Style / linting rules** — the configs (ESLint, Prettier, ruff) enforce them; CLAUDE.md doesn't repeat them.
- **Path-scoped rules** — those go in `.claude/rules/<name>.md`, not the main CLAUDE.md.
- **Workflow procedures** — those become their own skills under `~/.claude/skills/<name>/`.

These exclusions keep the file lean. Bloat weakens what Claude reads on every interaction.

---

## Flow

### 1. Detect stack

Read these without asking:

```bash
# Existing CLAUDE.md?
[[ -f CLAUDE.md ]] && existing=true

# Stack signals
[[ -f package.json ]] && stack_node=true
[[ -f pyproject.toml || -f setup.py || -f setup.cfg ]] && stack_python=true

# Framework signals (Node)
jq -r '.dependencies | keys[]' package.json 2>/dev/null
# Look for: next, react, fastify, express, vue, svelte, vite

# Framework signals (Python)
python3 -c "import tomllib; d=tomllib.load(open('pyproject.toml','rb')); print(' '.join(d.get('project',{}).get('dependencies',[])))" 2>/dev/null
# Look for: fastapi, django, flask, jupyter

# Layout
[[ -d frontend ]] && [[ -f frontend/package.json ]] && fullstack_subdirs=true

# No manifest at all -> toolbox/scripts repo (shell tools, editor-pasted sources, declarative config)
[[ -z $stack_node && -z $stack_python ]] && stack_toolbox=true
```

### 2. Handle existing CLAUDE.md

If `CLAUDE.md` already exists, **stop**:

> Found an existing CLAUDE.md. Three options:
> 1. Show me the current file — I'll read it and suggest additions/changes you can review by hand.
> 2. Overwrite (I'll save the original to `CLAUDE.md.bak`).
> 3. Skip — keep your current file as-is.

Wait for the user to pick. Don't algorithmically merge — CLAUDE.md content is user-written context that's expensive to lose silently.

### 3. Pick template

Map detection to template (see `references/templates.md`):

| Stack | Template |
|---|---|
| Next.js (App Router) | `Frontend / Fullstack-collapsed (Next.js)` |
| FastAPI | `Backend — Python (FastAPI)` |
| Fastify (no UI) | `Backend — Node (Fastify)` |
| Next.js + FastAPI fullstack | `Fullstack — Next.js + FastAPI` |
| Next.js + Fastify (workspaces) | `Fullstack — Next.js + Fastify (npm workspaces)` |
| Library project | `Library` (adapted from matching backend template) |
| Notebooks / research | `Research / notebooks` |
| No manifest (shell tools, editor-pasted sources, declarative config) | `Toolbox / scripts repo (no manifest)` |

If detection is ambiguous (e.g., both `package.json` and `pyproject.toml` with no framework), ask **once** to disambiguate.

### 4. Show summary, halt for confirmation

Render the plan as a code block with emoji headers:

```
🔍 Detected:        <stack summary>
📝 Template:        <picked variant>
📂 File to write:   CLAUDE.md (50-120 lines)
🛡️  Existing file:  <none | overwrite-with-backup | append-suggestions>
```

End with: *"Reply 'yes' / 'go' / 'looks good' to proceed, or tell me what to change."*

### 5. **HALT for confirmation**

Same gate as other skills.

---

## Execution

### 6. Backup existing file (only if user picked overwrite)

```bash
[[ -f CLAUDE.md ]] && cp CLAUDE.md CLAUDE.md.bak
```

Add `CLAUDE.md.bak` to `.gitignore` if not already ignored.

### 7. Write CLAUDE.md from the template

See `references/templates.md` for the per-stack template. Substitute:

- `<PROJECT_NAME>` — repo name (or the `name` field from `package.json` / `pyproject.toml`).
- One-line description — derive from existing README first paragraph if available; otherwise leave a `<placeholder>` for the user to fill.
- `<package_name>` (Python) — snake_case version of the project name.
- Project-specific paths — adjust `src/app/api/` etc. to match the actual layout if it differs.

### 8. Verify length

Re-read the written file and count lines. **Target: 50–120 lines.** If significantly outside that range:
- Under 50 lines → likely missing template sections; double-check the template was applied fully.
- Over 120 lines → review for content that belongs in `references/configs/`, `.claude/rules/`, README, or skill-level docs instead.

Don't auto-trim. Surface to the user.

### 9. Report back

- ✅ Template used
- ✅ File written (line count)
- ⚠️ Any backup created (path)
- 📋 Next steps:

```
Next steps:
1. Open CLAUDE.md and replace any <placeholder> markers with project-specific values
2. Skim the file — anything that's wrong or missing is much better fixed now than after the file goes stale
3. Commit it: `git add CLAUDE.md && git commit -m "chore: add CLAUDE.md"`
```

---

## Reference files

- `references/templates.md` — per-stack CLAUDE.md templates (Next.js, FastAPI, Fastify, fullstack variants, library, research, toolbox/scripts)

## Why these defaults

- **Lean target (50–120 lines)** — bloat weakens what Claude reads. The file is loaded into every conversation in the repo; bigger isn't better.
- **Lean against the global CLAUDE.md** — the user's `~/.claude/CLAUDE.md` already covers git workflow, link formatting, link rules, etc. Per-repo files only add what's repo-specific.
- **Refuse to overwrite silently** — CLAUDE.md is hand-curated context. Auto-merging risks losing important user-written notes.
- **Templates are starting points, not contracts** — the user is expected to edit the file. Surfacing line count helps them notice when their edits make it bloat.

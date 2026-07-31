# Unified Pre-Commit Config (Root)

**Pre-commit at repo root, single config, polyglot.** Replaces husky + lint-staged entirely. Works for every stack combo: Python-only, Node-only, fullstack.

## Why pre-commit and not husky

| | husky + lint-staged | pre-commit |
|---|---|---|
| Origin | Node ecosystem | Python ecosystem |
| Polyglot repos | Awkward — write shell to dispatch by file extension | Native — each hook declares which file types it runs on |
| Updates | Manual (you manage versions of each tool) | `pre-commit autoupdate` bumps everything |
| Hook ecosystem | DIY | Versioned community-maintained hooks for every language |
| Polyglot fullstack | Two systems coexisting awkwardly | One config covers everything |

**Verdict: pre-commit wins for everything except trivial Node-only projects, and even there it's not worse.** Default to pre-commit, drop husky from the skill entirely.

## Setup

```bash
pip install pre-commit  # or: uv add --dev pre-commit
```

**Important: `pre-commit install` requires `.git/` to exist.** It writes the hook script to `.git/hooks/pre-commit`. If the skill is following Step 13 before Step 15 (git init), defer the `pre-commit install` call until after `git init`. In `project-scaffold`'s flow, Step 15 handles installation **before** the initial commit and runs the auto-fixers against the working tree once, so the initial commit lands clean (see `project-scaffold/references/step-15-git-init.md`).

```bash
# Run AFTER git init, BEFORE the initial commit:
pre-commit install
pre-commit autoupdate
git add .
pre-commit run --all-files || true   # apply auto-fixers
git add .
git commit -m "chore: initial scaffold"
```

`pre-commit install` writes `.git/hooks/pre-commit` so hooks fire on every commit, regardless of which subdir you commit from. Pre-commit always runs from the repo root.

`pre-commit autoupdate` (run before the first commit) bumps hook revisions to current versions so the user doesn't start out on stale ones.

For retrofit cases (existing repo, no scaffold flow), `pre-commit install` happens once after writing the config — no special ordering required, since there's no fresh initial commit to keep clean.

---

## Config: Python-only

`.pre-commit-config.yaml` (revs are current at scaffold time — `pre-commit autoupdate` runs automatically in Step 15 to bump them, and you can re-run it periodically):

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: check-merge-conflict
      - id: check-toml

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.12
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.20.2
    hooks:
      - id: mypy
        # Hooks run in pre-commit's isolated env. mypy needs the project's
        # third-party deps to type-check imports correctly. Add anything used
        # in source modules (not just tests) here.
        additional_dependencies:
          - fastapi>=0.115
          - pydantic>=2.9
          - pytest>=8.0
          - httpx>=0.27
        args: [--config-file=pyproject.toml]
```

**The `additional_dependencies` block matters.** Without it, mypy can't resolve `from fastapi import FastAPI` and pre-commit fails on the very first run. Update this list as the project's runtime deps change.

---

## Config: Node-only (Next.js or Fastify)

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: check-merge-conflict

  # Use language: system hooks so they run against the project's installed
  # eslint/prettier (with the project's full config), not pre-commit's isolated env.
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint --fix
        language: system
        files: \.(ts|tsx|js|jsx|mjs|cjs)$
        exclude: ^(node_modules/|dist/|build/|\.next/|out/)
        pass_filenames: true

      - id: prettier
        name: prettier
        entry: npx prettier --write
        language: system
        files: \.(ts|tsx|js|jsx|mjs|cjs|json|css|scss|md)$
        exclude: ^(node_modules/|dist/|build/|\.next/|out/|package-lock\.json)
        pass_filenames: true

      - id: typecheck
        name: typecheck
        entry: npm run typecheck
        language: system
        pass_filenames: false
        types: [ts]
```

Note `mjs` and `cjs` are in **both** eslint and prettier file patterns. Without `mjs` in the prettier pattern, Next.js's `eslint.config.mjs` never gets formatted by pre-commit, and CI's `format:check` fails on first push.

YAML (`yml`/`yaml`) is intentionally **absent** from the prettier pattern — prettier doesn't format YAML in these scaffolds. Its YAML formatting mangles GitHub Actions workflow files (reflowing inline comments) for zero benefit, and the generated `.prettierignore` also excludes `*.yml`/`*.yaml` (see `project-scaffold/references/configs/node-ts.md`). Don't re-add it here.

The `language: system` approach runs from the project's installed binaries so the project's full ESLint/Prettier config (including plugins) applies. The `mirrors-eslint` repo from pre-commit's registry runs ESLint in an isolated env that doesn't see your local plugins, which is why we don't use it.

---

## Config: Python + TS Fullstack (separate frontend/backend dirs)

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: check-merge-conflict
      - id: check-toml

  # Python (backend/) hooks
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.12
    hooks:
      - id: ruff-check
        args: [--fix]
        files: ^backend/.*\.py$
      - id: ruff-format
        files: ^backend/.*\.py$

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.20.2
    hooks:
      - id: mypy
        files: ^backend/.*\.py$
        # Required so mypy can resolve project imports in its isolated env
        additional_dependencies:
          - fastapi>=0.115
          - pydantic>=2.9
          - pytest>=8.0
          - httpx>=0.27
        args: [--config-file=backend/pyproject.toml]

  # TS (frontend/) hooks — local so they use the project's full config
  - repo: local
    hooks:
      - id: eslint
        name: eslint (frontend)
        entry: |
          bash -c '
            cd frontend
            files=()
            for f in "$@"; do files+=("${f#frontend/}"); done
            [ ${#files[@]} -eq 0 ] || npx eslint --fix "${files[@]}"
          ' --
        language: system
        files: ^frontend/.*\.(ts|tsx|js|jsx|mjs|cjs)$
        pass_filenames: true

      - id: prettier
        name: prettier (frontend)
        entry: |
          bash -c '
            cd frontend
            files=()
            for f in "$@"; do files+=("${f#frontend/}"); done
            [ ${#files[@]} -eq 0 ] || npx prettier --write "${files[@]}"
          ' --
        language: system
        files: ^frontend/.*\.(ts|tsx|js|jsx|mjs|cjs|json|css|scss|md)$
        pass_filenames: true
```

**Critical detail about the `bash -c` wrappers**: pre-commit passes paths relative to the repo root (e.g. `frontend/src/app/page.tsx`). After `cd frontend`, those root-relative paths no longer resolve — eslint/prettier error with "no files matching pattern". The wrapper strips the `frontend/` prefix from each arg before passing to the tool.

The bare `cd frontend && npx eslint "$@"` pattern (without prefix stripping) **does not work**, even though it looks like it should.

If staging only Python files, only Python hooks run. If staging only TS files, only TS hooks run. Mixing runs both. **All from root, no matter where you ran `git commit`.**

---

## Config: Node + Node Fullstack (npm workspaces)

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: check-merge-conflict

  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint --fix
        language: system
        files: \.(ts|tsx|js|jsx|mjs|cjs)$
        exclude: ^(node_modules/|dist/|build/|\.next/|out/)
        pass_filenames: true

      - id: prettier
        name: prettier
        entry: npx prettier --write
        language: system
        files: \.(ts|tsx|js|jsx|mjs|cjs|json|css|scss|md)$
        exclude: ^(node_modules/|dist/|build/|\.next/|out/|package-lock\.json)
        pass_filenames: true

      - id: typecheck
        name: typecheck
        entry: npm run typecheck
        language: system
        pass_filenames: false
```

For npm workspaces, the root `eslint.config.js` re-exports from the workspaces, or each workspace has its own and ESLint resolves correctly when called from root.

---

## Manual invocation

Users can also run pre-commit manually from root:

```bash
pre-commit run --all-files          # run on every file in the repo
pre-commit run --files <path>       # run on specific files
pre-commit run ruff-check --all-files     # run only the ruff lint hook
```

Useful when adding pre-commit to an existing project or after changing config.

The skill scaffolds a wrapper script as a convenience:

```json
// in package.json scripts (or scripts/dev.py for Python-only):
"pre-commit": "pre-commit run --all-files"
```

So users can just `npm run pre-commit` from anywhere in a Node project.

---

## Notes

- `pre-commit autoupdate` bumps all hook versions in this file at once. Run periodically.
- Don't put `pytest` or `vitest` here. Tests belong in CI. Pre-commit should be fast (<5s ideally).
- Bypass with `git commit --no-verify` in emergencies. CLAUDE.md says don't.

# Step 20 — Smoke test

Before declaring success, run a smoke test from the project root. **Don't use empty commits** — invoke hooks directly so there's no commit cleanup needed.

## Sequence

```bash
# 1. Verify deps install cleanly
if [[ -f package.json ]]; then npm install; fi
if [[ -f pyproject.toml ]]; then pip install -e ".[dev]"; fi

# 2. Verify linter finds its config and runs
npm run lint                # if Node
ruff check .                # if Python

# 3. Verify typecheck passes
npm run typecheck           # if TS
mypy .                      # if Python

# 4. Verify hooks fire correctly (without making a commit)
pre-commit run --all-files

# 5. Verify test runner finds tests and they pass
npm run test                # if Node
pytest                      # if Python

# 6. Verify production build succeeds
# This catches server-component issues, env-var misses, broken imports,
# and other failures that lint/typecheck/test don't catch.
npm run build               # if Node
python -m build             # if Python

# 7. Verify check:all (lint, format check, typecheck, and tests) passes
npm run check:all           # if Node
python scripts/dev.py check:all   # if Python-only
```

## Common failure modes and fixes

- **ESLint can't find config** → may need root-level config for monorepo layouts
- **`tsc --noEmit` fails on empty `src/`** → may need stub source files
- **Test runner not installed** → install vitest/pytest as dev deps (see `references/step-E-test-stubs.md`)
- **`format:check` fails on `eslint.config.mjs`** → run `npx prettier --write .` after writing `.prettierrc`
- **mypy fails on imports** → check `additional_dependencies` in `.pre-commit-config.yaml`
- **`npm run build` fails on Next.js scaffold** → check for missing env vars or bad server-component imports

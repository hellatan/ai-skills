# Root `package.json` Scripts

Cross-platform command runner for any project with a Node component. Replaces Make (which isn't Windows-friendly). Lives at repo root regardless of stack.

`npm run check:all` runs lint, format check, typecheck, and tests. Build and
end-to-end checks remain separate commands when configured.

The convenience wrapper for hooks is **`npm run pre-commit`** — runs `pre-commit run --all-files` from anywhere in the project.

---

## Why `concurrently` for `dev`

The naive `npm run dev:frontend & npm run dev:backend` uses `&` for backgrounding, which has problems:
- Single Ctrl-C only kills the foreground process; the backgrounded one keeps running
- Output from both processes interleaves with no labels
- Doesn't work on Windows cmd.exe

Using the `concurrently` package solves all three: it runs both in parallel, prefixes output with which one is which, and Ctrl-C kills both. Add it as a root dev dep.

---

## Node-only or Next.js-only (single project at root)

Already covered by the project's own `package.json` — no separate root config needed. Just ensure `check:all` and `pre-commit` are in scripts:

```json
{
  "scripts": {
    "check:all": "npm run lint && npm run format:check && npm run typecheck && npm run test",
    "pre-commit": "pre-commit run --all-files"
  }
}
```

If a database was scaffolded (Step 4), this same `package.json` also carries the `db:generate` / `db:migrate` / `db:push` / `db:studio` scripts — see `database-drizzle.md`.

---

## Python + TS Fullstack (independent projects)

Root `package.json`:

```json
{
  "name": "<project-name>-root",
  "private": true,
  "version": "0.1.0",
  "description": "Root scripts for running everything across the repo",
  "scripts": {
    "lint": "npm run lint:frontend && npm run lint:backend",
    "lint:frontend": "npm --prefix frontend run lint",
    "lint:backend": "cd backend && ruff check . && mypy .",

    "format": "npm run format:frontend && npm run format:backend",
    "format:frontend": "npm --prefix frontend run format",
    "format:backend": "cd backend && ruff format .",

    "format:check": "npm run format:check:frontend && npm run format:check:backend",
    "format:check:frontend": "npm --prefix frontend run format:check",
    "format:check:backend": "cd backend && ruff format --check .",

    "typecheck": "npm run typecheck:frontend && npm run typecheck:backend",
    "typecheck:frontend": "npm --prefix frontend run typecheck",
    "typecheck:backend": "cd backend && mypy .",

    "test": "npm run test:frontend && npm run test:backend",
    "test:frontend": "npm --prefix frontend test",
    "test:backend": "cd backend && pytest",

    "build": "npm run build:frontend && npm run build:backend",
    "build:frontend": "npm --prefix frontend run build",
    "build:backend": "cd backend && python -m build",

    "dev": "concurrently -n frontend,backend -c blue,green \"npm run dev:frontend\" \"npm run dev:backend\"",
    "dev:frontend": "npm --prefix frontend run dev",
    "dev:backend": "cd backend && uvicorn <package_name>.main:app --reload",

    "check:all": "npm run lint && npm run format:check && npm run typecheck && npm run test",
    "pre-commit": "pre-commit run --all-files"
  },
  "devDependencies": {
    "concurrently": "^9.0.0"
  }
}
```

Replace `<package_name>` with the snake_case Python package name from Step 1.

---

## Node + Node Fullstack (npm workspaces)

Root `package.json`:

```json
{
  "name": "<project-name>",
  "private": true,
  "version": "0.1.0",
  "workspaces": ["frontend", "backend", "shared"],
  "scripts": {
    "lint": "npm run lint --workspaces --if-present",
    "format": "npm run format --workspaces --if-present",
    "format:check": "npm run format:check --workspaces --if-present",
    "typecheck": "npm run typecheck --workspaces --if-present",
    "test": "npm run test --workspaces --if-present",
    "build": "npm run build --workspaces --if-present",
    "dev": "concurrently -n frontend,backend -c blue,green \"npm --workspace=frontend run dev\" \"npm --workspace=backend run dev\"",
    "check:all": "npm run lint && npm run format:check && npm run typecheck && npm run test",
    "pre-commit": "pre-commit run --all-files"
  },
  "devDependencies": {
    "prettier": "^3.3.3",
    "@ianvs/prettier-plugin-sort-imports": "^4.4.0",
    "concurrently": "^9.0.0"
  }
}
```

Workspaces inherit dev deps from root, so prettier and the sort-imports plugin live at root.

---

## Python-only

No root `package.json` — npm wouldn't be installed. Use `scripts/dev.py` instead. See `python-dev-script.md` (which now also includes a `pre-commit` command alias).

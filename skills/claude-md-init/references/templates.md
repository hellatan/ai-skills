# CLAUDE.md Templates

Pick the template that matches the project type/stack. All templates inherit the global rules from `~/.claude/CLAUDE.md` (git workflow, link formatting), so the per-repo file only adds **project identity**, **canonical commands**, and **non-obvious gotchas**.

Aim for 50–120 lines total.

## Workflow-rule reference (every template)

When the project ships with `.claude/rules/git-workflow.md` (which `/project-scaffold` Step 10 writes by default), include this line near the top of the CLAUDE.md, right under the project description:

```markdown
@.claude/rules/git-workflow.md
```

The `@<path>` directive tells Claude sessions to load the referenced file as additional context, so the per-repo workflow rules apply automatically without depending on the user's global agent memory. Skip this line when retrofitting a CLAUDE.md into a repo that doesn't already have the workflow rule file.

## Architecture-doc reference (every template)

When the project ships with `docs/architecture.html` (which `/project-scaffold` Step 10 writes by default, and `/architecture-doc-init` retrofits onto existing repos — template in `architecture-doc-init/references/architecture-doc-template.md`), add this bullet to the CLAUDE.md `## Project map` section:

```markdown
- `docs/architecture.html` — living system map (open in a browser). Update it when components, flows, or failure modes change.
```

This makes the visual map discoverable to any contributor or Claude session working on the repo. Skip the bullet when retrofitting a CLAUDE.md into a repo that has no `docs/architecture.html`.

## Living-doc note (every template)

Add this line right under the project one-liner (after the `@.claude/rules/git-workflow.md` directive, when present) in every generated CLAUDE.md:

```markdown
> **Living doc:** when you learn a durable, non-obvious fact about this repo (a gotcha, convention, or footgun), add it to the matching section of this file in the same PR — don't leave it in chat.
```

Without it, hard-won repo knowledge surfaces in a session, gets used once, and evaporates; this line makes CLAUDE.md the designated landing place. The same lean rules still apply — durable and non-obvious only, and the 50–120 line budget is the backstop against the note becoming a dumping-ground license.

## Conventions every template should include

These cross-cutting conventions caused real breakage on past scaffolds. They're already baked into every template's `## Conventions` block below (with stack-appropriate wording; the env-lazy rule is omitted where nothing imports app code at build time, e.g. research) — keep them when customizing. The canonical rationale lives here, once:

- **Don't write `BREAKING CHANGE:` or `feat!:` in commit-body prose unless you mean them.** Conventional-commits / release-please parsers match these patterns liberally and will inject a bogus `⚠ BREAKING CHANGES` section into the CHANGELOG. Paraphrase when referring to them ("the breaking-change footer", "the bang-suffix on `feat`").
- **Env-reading modules must be lazy — throw on first *use*, not at module eval.** A db client / storage client / SDK initializer that throws at import time when an env var is unset will crash `next build` (and any type-check or page-data-collection step that imports it) in CI, where those env vars typically aren't set. Read the env var inside the function/route that needs it, or rely on lazy clients (e.g. `pg.Pool` doesn't connect until the first query). Applies to db clients, storage clients, and third-party SDKs (Stripe, Sentry, etc.).

For frontend/Next.js templates, also include the **styling convention** matching the choice made at scaffold time (CSS Modules is the default — see `project-scaffold/references/configs/styling-css-modules.md`).

---

## Universal preamble (always include)

```markdown
# <PROJECT_NAME>

<One-line description of what this repo is and what stack.>

@.claude/rules/git-workflow.md

> **Living doc:** when you learn a durable, non-obvious fact about this repo (a gotcha, convention, or footgun), add it to the matching section of this file in the same PR — don't leave it in chat.

## Lifecycle

- Feature branches off `develop`, never `main`.
- PRs target `develop`. CI must pass before merge.
- Release: PR `develop` → `main` (or `develop` → `stage` → `main` if staging is enabled). release-please opens a release PR with version bump + changelog. Merging the release PR tags the commit and triggers deploy.
- See `.github/workflows/` for the full pipeline.

## Project map

<2–6 bullets describing top-level directories.>

## Canonical commands

Run from the repo root:

- `npm run check:all` — runs everything CI would run (lint + typecheck + tests)
- `npm run lint` / `npm run format` / `npm run test` / `npm run build` — individual steps
- `npm run dev` — start dev server(s)
- `pre-commit run --all-files` — manually run all pre-commit hooks
```

(Python-only projects: replace `npm run` with `python scripts/dev.py`.)

---

## Frontend / Fullstack-collapsed (Next.js)

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Trading dashboard. Next.js 15 + TypeScript.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop`, never `main`.
- Pre-commit runs ESLint + Prettier on staged files. Don't bypass with `--no-verify`.
- PRs target `develop`. CI runs the full check suite (lint+typecheck, format:check, unit, e2e, build — plus integration if opted in).
- Releases: merge `develop` → `main` → release-please PR → tag → deploy.

## Project map

- `src/app/` — Next.js App Router pages and layouts
- `src/components/` — React components
- `src/lib/` — utilities, API clients, shared logic
- `src/app/api/` — backend API routes (this is the "backend")
- `public/` — static assets

## Canonical commands

- `npm run dev` — dev server (frontend + API routes together)
- `npm run check:all` — full CI suite locally
- `npm run lint` / `npm run typecheck` / `npm run test` / `npm run build`
- `npm run test:e2e` — Playwright end-to-end tests

## Conventions

- TypeScript strict mode is on. Don't disable it.
- Imports: type imports first (sorted), then value imports (sorted). Prettier handles this automatically.
- Imports use the `@/` alias for `src/`.
- **Styling: CSS Modules.** Co-locate a `*.module.css` per component; reference `className={styles.x}`. No inline `style={{...}}` (beyond truly dynamic values), no Tailwind utility classes. (Replace this line with the chosen styling approach if not CSS Modules.)
- **Env-reading modules are lazy** — throw on first use, not at module eval, or `next build` crashes in CI where env vars are unset.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
- Conventional commits required (release-please drives off them).
```

---

## Backend — Python (FastAPI)

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Charting API. FastAPI + pandas. Python 3.12.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop`, never `main`.
- Pre-commit runs ruff (lint + format) and mypy on staged files.
- PRs target `develop`. CI runs the full check suite.
- Releases via release-please.

## Project map

- `<package_name>/` — main package
- `<package_name>/main.py` — FastAPI app entry
- `tests/` — pytest test suite
- `scripts/` — one-off CLI entry points

## Canonical commands

- `uvicorn <package_name>.main:app --reload` — dev server (interactive docs at http://localhost:8000/docs)
- `python scripts/dev.py check:all` — full CI suite locally
- `python scripts/dev.py lint` / `format` / `test` / `typecheck`

## Conventions

- Python 3.12+ required.
- Async-first — handlers should be `async def` unless you have a reason otherwise.
- **Env-reading modules are lazy** — read env vars inside the function/dependency that needs them, not at import time; CI and pytest collection import modules with no prod env vars set.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
- Conventional commits required.
```

---

## Backend — Node (Fastify, separate from Next.js)

Use this only when the user explicitly opted out of the Next.js-only fullstack default. Otherwise the Next.js template above covers backend.

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Order execution service. Fastify + TypeScript.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop`, never `main`.
- Pre-commit runs ESLint + Prettier on staged files.
- PRs target `develop`. CI runs the full check suite.
- Releases via release-please.

## Project map

- `src/` — application code
- `src/routes/` — Fastify route handlers
- `src/services/` — business logic
- `src/db/` — data access layer

## Canonical commands

- `npm run dev` — dev server with hot reload
- `npm run check:all` — full CI suite locally
- `npm run lint` / `npm run typecheck` / `npm run test` / `npm run build`
- `npm start` — production server

## Environment

- Required env vars are documented in `.env.example`. Copy to `.env` for local dev.

## Conventions

- Conventional commits required.
- TypeScript strict mode is on.
- Imports: type imports first (sorted), then value imports (sorted).
- **Env-reading modules are lazy** — throw on first use, not at module eval, or build/typecheck crashes in CI where env vars are unset.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
```

---

## Fullstack — Next.js + FastAPI (two independent projects)

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Trading dashboard. Next.js frontend + FastAPI Python backend.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop`. PRs target `develop`. CI runs the full check suite across both sides.
- Pre-commit at repo root runs the right hooks based on which files you've staged (Python files → ruff + mypy; TS files → ESLint + Prettier).
- Releases via release-please.

## Project map

- `frontend/` — Next.js + TypeScript
- `backend/` — Python FastAPI app
- `.github/workflows/` — CI + release-please + deploy
- `.pre-commit-config.yaml` — single root config covering both stacks

## Canonical commands (run from repo root)

- `npm run dev` — starts both frontend and backend dev servers
- `npm run check:all` — full CI suite locally (lint + typecheck + tests, both stacks)
- `npm run lint` / `format` / `test` / `typecheck` / `build` — runs against both stacks
- `npm run lint:frontend` / `lint:backend` (and same for other commands) — single side

## Conventions

- Frontend talks to backend via `NEXT_PUBLIC_API_URL` env var.
- API routes are versioned (`/api/v1/...`).
- **Env-reading modules are lazy** — throw on first use, not at module eval; `next build` and pytest collection run in CI with no prod env vars set.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
- Conventional commits required.
```

---

## Fullstack — Next.js + Fastify (npm workspaces)

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Trading platform. Next.js frontend + Fastify backend, npm workspaces.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop`. PRs target `develop`. CI runs the full check suite.
- Pre-commit at repo root.
- Releases via release-please.

## Project map

- `frontend/` — Next.js + TypeScript
- `backend/` — Fastify + TypeScript
- `shared/` — shared types between backend and frontend (if needed)
- Root `package.json` defines workspaces and orchestrates cross-stack scripts

## Canonical commands (run from repo root)

- `npm install` — installs everything across workspaces
- `npm run dev` — starts both
- `npm run check:all` — full CI suite locally
- `npm run lint` / `format` / `test` / `typecheck` / `build`

## Conventions

- Shared types live in `shared/` and are imported via `@<project>/shared`.
- Conventional commits required.
- TypeScript strict mode in both workspaces.
- **Env-reading modules are lazy** — throw on first use, not at module eval, or builds/typechecks crash in CI where env vars are unset.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
```

---

## Library

Use the matching backend template above as a starting point and:
- Replace "service" / "app" language with "library" / "package"
- Add a "Publishing" section — release-please handles tagging; publish step lives in `deploy.yml`
- Drop the "Environment" section if not relevant

---

## Research / notebooks

```markdown
# <PROJECT_NAME>

<One-liner: e.g., "Exploratory backtest research for MNQ breakout strategies.">

@.claude/rules/git-workflow.md

## Lifecycle

- Feature branches off `develop` for non-trivial work. Trivial notebook tweaks can go on `develop` directly.
- Pre-commit runs ruff on `.py` files (notebooks excluded).
- CI is lighter for research projects — lint + smoke-test notebooks.

## Project map

- `notebooks/` — Jupyter notebooks, dated and named by topic
- `data/` — input data (gitignored if large)
- `outputs/` — generated charts, reports (gitignored)
- `lib/` — reusable Python helpers

## Canonical commands

- `jupyter lab` — launch notebook server
- `python scripts/dev.py lint` — lint helper modules
- `pre-commit run --all-files` — manual full-repo lint

## Conventions

- Notebooks are named `YYYY-MM-DD_topic.ipynb`.
- Heavy data and generated outputs are gitignored.
- **Don't write `BREAKING CHANGE:` / `feat!:` in commit-body prose** unless you mean them — parsers will corrupt the CHANGELOG. Paraphrase instead.
```

---

## Toolbox / scripts repo (no manifest)

For repos with no `package.json` / `pyproject.toml` at all — shell-script tools, editor-pasted
sources (e.g. Pine Script indicators), declarative config/data repos where committing *is*
deploying. There's no install/build/test loop to document, so this template swaps
"Canonical commands" for "How work ships" and spends the line budget on gotchas.

If the repo has one rule that most often bites (a deploy model, a two-lane commit
convention, a "never edit X directly"), promote it to the first section with a heading that
names it — don't bury it mid-file.

```markdown
# <PROJECT_NAME>

<One-liner: what the repo holds and where its output lands.>

## Lifecycle

- <Branch model. Many toolbox repos are main-only: feature branches off `main`, PRs target
  `main`. If the repo has `develop`, use the universal preamble's lifecycle instead.>
- <Versioning/release if any — often none: merging is shipping.>

## Project map

- <2–6 bullets for top-level dirs/files. Load-bearing script(s) first.>

## How work ships

<The actual delivery mechanism, one bullet per path, e.g.:>
- <`./publish.sh <file>` — what it does end-to-end, and how to verify it worked>
- <"paste into <external editor/tool>" — plus the pre-save check that prevents pasting into
  the wrong target>
- <"commit `<dir>/*.yml` to <branch>" — and what picks it up, where, when>

## Gotchas

- <Only non-obvious, hard-won facts: footguns, environment quirks, silent-failure modes.
  Mine the git fix/revert history and the `docs/architecture.html` failure-modes table.>
```

Notes:
- These repos live or die on the Gotchas section — the "commands" are usually trivial; the
  sharp edges are not.
- Include the `BREAKING CHANGE:` / `feat!:` convention bullet only if the repo runs release
  tooling; drop it otherwise.
- Same retrofit rules as every template: skip `@.claude/rules/git-workflow.md` unless the
  file exists, and add the architecture-doc Project-map bullet only when
  `docs/architecture.html` exists.

---

## What NOT to put in any of these templates

- Linter/formatter rules (the configs themselves enforce them)
- Style rules inferable from existing code
- Hotfix-style instructions
- Path-scoped rules (move to `.claude/rules/<name>.md`)
- Workflow procedures (move to `.claude/skills/<name>/SKILL.md`)
- Anything already in the README or `package.json` / `pyproject.toml`

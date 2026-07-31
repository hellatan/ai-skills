---
name: project-scaffold
description: Bootstrap a new project repo with prescriptive defaults — opinionated framework picks (Next.js, FastAPI), lean CLAUDE.md, sensible git workflow (main + develop, optional stage), unified pre-commit hooks at root, GitHub Actions CI (consolidated checks/e2e/build pipeline), release-please for automated releases, deploy workflow stub, and a private GitHub repo under the user's authenticated gh account. Use this skill whenever the user wants to scaffold, bootstrap, initialize, or set up a new project, repo, or codebase — even if they don't explicitly say "scaffold." Triggers on phrases like "new repo," "start a new project," "bootstrap [name]," "set up a project," or "init a repo with claude config."
---

# project-scaffold

Bootstraps a new project repo with prescriptive, opinionated defaults. The goal is a project that's wired correctly end-to-end on day one — feature → develop → main → tag → deploy works out of the box, with sensible framework picks already made for users who don't have strong opinions.

## Core philosophy: prescriptive defaults, named overrides

For every decision the skill makes:

1. **Pick the best default** based on the user's stated project type.
2. **State it as a fact**, not a question: "Going with X for Y — [one-line outcome explanation]."
3. **Offer a named override**: "If you specifically need [alternative], say so now."
4. **Allow trivial confirmation**: "Otherwise reply 'ok' or hit enter."

Most users don't have strong opinions on most decisions. Even users who could answer often don't want to — decision fatigue is real. Naming alternatives gives experienced users a clean exit without forcing newbies to learn what they don't know yet. Outcome-based explanations beat jargon-based labels every time.

**Avoid jargon when explaining defaults.** Describe what the user gets, not the architectural buzzword. "Free interactive API docs" beats "automatic OpenAPI generation." "Handles your whole web app in one framework" beats "covers SSR and API routes."

## When to trigger

User says any of:
- "scaffold a new repo / project"
- "bootstrap [project-name]"
- "set up a new [stack] project"
- "init a new repo"
- "new project with claude config"

## Requires

Both `/testing-init` and `/gh-actions-init` must be installed (Step 14 delegates to them). See `references/sister-skills-dependency.md`.

---

## Flow

Run these steps in order. **Ask questions one at a time.** For decision points where the skill has a strong default, state the default and only wait for an override.

### 1. Verify sister skills are installed (fail fast)

Before Step 2, confirm `/testing-init` and `/gh-actions-init` are in the available-skills list. If either is missing, abort with the message in `references/sister-skills-dependency.md` — don't ask the user any questions until the dependency is satisfied.

### 2. Project name + location

Ask:
- Project name (becomes repo name and directory name)
- Parent directory (default: current working directory)

Verify the target directory doesn't already exist before proceeding.

Compute the **package name** here too: convert the project name to snake_case for Python (e.g. `my-project` → `my_project`). This name will be propagated consistently to:
- `pyproject.toml` `name` field
- The actual package directory + `__init__.py`
- `uvicorn <package>.main:app` references in CLAUDE.md
- Test discovery paths

### 3. Project type

Ask:

> What is this project?
> - **frontend** — a website or web app that users interact with in their browser
> - **backend** — a server that handles data, APIs, or background work (no visible UI)
> - **fullstack** — both: a website *plus* a server it talks to
> - **library** — code meant to be reused by other projects (published as a package)
> - **research** — exploratory work, notebooks, scripts — no app or website to deploy

### 4. Framework selection (prescriptive)

Apply the prescriptive-defaults pattern. Don't ask what they want — tell them what you're using.

**For frontend or fullstack with a frontend:**

> Going with **Next.js** for the frontend — it's the most flexible choice and handles your whole web app in one framework (pages, APIs, the works). If you specifically need something else (Vite + React, SvelteKit, Vue, etc.), say so now. Otherwise reply "next is fine" or just hit enter.

**Then pick a styling approach (ask — this one's a real preference, not a prescribed default to skip past):**

> How do you want to style it? Default is **CSS Modules** — scoped `.module.css` files per component, no utility-class soup, no extra dependencies.
>
> - **CSS Modules** (default) — scoped CSS per component
> - **Vanilla Extract** — type-safe, zero-runtime CSS-in-TS (`*.css.ts`)
> - **Tailwind** — utility-first classes (available if you want it)
> - **Tailwind + shadcn/ui** — Tailwind plus a prebuilt component library
>
> Reply with a choice or hit enter for CSS Modules.

CSS Modules is the default and the recommended pick. Tailwind stays available for anyone who prefers it, but never lead with it or present it as the recommendation. Wire the choice through:
- **CSS Modules** → pass `--no-tailwind` to `create-next-app`; don't install shadcn. Scaffold example UI as `*.module.css` (no inline `style={{...}}`) and include the styling convention in the generated CLAUDE.md / rules (see `references/configs/styling-css-modules.md`).
- **Vanilla Extract** → pass `--no-tailwind`; don't install shadcn. Add `@vanilla-extract/css` + `@vanilla-extract/next-plugin`, wrap `next.config` with `createVanillaExtractPlugin()`, and co-locate styles as `*.css.ts` (see `references/configs/styling-css-modules.md`).
- **Tailwind** → omit `--no-tailwind`; don't install shadcn.
- **Tailwind + shadcn/ui** → omit `--no-tailwind`; run shadcn init.

**For backend or fullstack with a backend, ask the language first IF context is unclear:**

For the backend language question, **don't be prescriptive about Python vs Node** — instead, prompt the user to describe the project's purpose, then diagnose:

> What does the backend mainly do? (e.g. "serves an API for the frontend", "runs charting calculations", "processes uploaded data", "does ML inference"). I'll pick the right language based on use case.

Use the description to recommend:
- **Charting, data analysis, ML, scientific computing, quant work, anything numerical-heavy** → recommend Python with reasoning ("Python's ecosystem for numerical work is unmatched — pandas, numpy, scipy, matplotlib all live here. You'd fight Node.js the whole way.")
- **APIs, web services, real-time, general business logic** → recommend Node with reasoning ("Node is great for HTTP APIs and shares the language with your TypeScript frontend, which means easier type sharing.")
- **If they explicitly state a language preference** → respect it but flag if it seems mismatched ("You said Node, but you mentioned charting — are you sure? Python would be much easier here.")

**Then commit to the framework:**

For Python backend:
> Going with **FastAPI** — modern, fast, and gives you free interactive API docs. If you specifically need Django (heavier, comes with admin UI and built-in user accounts) or Flask (tiny and barebones — you build everything yourself), say so now. Otherwise reply "fastapi is fine" or just hit enter.

For Node backend (when not collapsed into Next.js):
> Going with **Fastify** — modern, fast, type-friendly. If you specifically need Express (the classic, more middleware available) or Hono (works on edge runtimes), say so now. Otherwise reply "fastify is fine" or just hit enter.

**Important: for Node + Node fullstack, default to collapsing into Next.js alone.**

> For a fullstack JS/TS project, going with **just Next.js** — its built-in API routes handle the backend, so you don't need a separate Node service. Simpler to deploy, easier to share types between frontend and backend.
>
> If you specifically need a separate backend (e.g. you'll have multiple frontends, heavy background jobs, or websockets), say so now. Otherwise reply "ok" or hit enter.

**Then, for any app with a server side (frontend with API routes, fullstack, or backend), ask about a database (opt-in):**

Skip this entirely for **research**, **library**, and pure static frontend projects — they don't persist data.

> Does this project need a database? (yes/no)
>
> A database stores data that has to survive between visits — user accounts, posts, orders, anything you'd otherwise lose on restart. If you're not sure yet, say no; it's easy to add later.

If **no**, skip both this and the auth question below. If **yes**, pick the host:

> Where should Postgres live? Default is **Neon**.
>
> - **Neon** (default) — serverless Postgres, branchable, generous free tier
> - **Render Postgres** — co-located with the default deploy target
> - **Supabase** — Postgres plus a dashboard and extras
> - **local Docker** — a container on your machine (no managed host yet)
>
> Reply with a choice or hit enter for Neon.

Postgres + **Drizzle** (ORM) + `drizzle-zod` is scaffolded regardless of host — see `references/configs/database-drizzle.md` for the client, `drizzle.config.ts`, `db:*` scripts, `.env.example` `DATABASE_URL`, and per-host connection strings. The host answer also drives which `render.yaml` variant `gh-actions-init` emits (Render-managed `databases:` block vs. an external-DB `sync: false` secret).

**Then, only when the project has a database, ask about authentication (opt-in):**

> Add authentication (user sign-up / login)? (yes/no)
>
> - **Better Auth** (default) — TypeScript-native, owns its schema, works with your Drizzle setup
> - **Auth.js / NextAuth** — the long-standing option, more prebuilt OAuth providers
>
> Reply yes (Better Auth), "Auth.js", or no.

Never offer auth when the user declined a database — Better Auth persists users/sessions and depends on the DB. **Better Auth is the default and recommended pick; Auth.js stays selectable but never led with** (same posture as CSS Modules vs Tailwind). See `references/configs/auth-better-auth.md` for the adapter wiring, route handler, the `@better-auth/cli generate` → Drizzle migration flow, and the `BETTER_AUTH_SECRET` / `BETTER_AUTH_URL` env vars.

### 5. Layout decision (fullstack only)

This decision depends on the backend language.

**Node + Node fullstack (when user opts for separate backend, not Next.js-only):**

> Going with **npm workspaces** for the layout — `frontend/` and `backend/` share dependencies and let you import types between them, with one `npm install` at the root. This is what npm workspaces was built for.
>
> The repo root also holds the shared coordination layer: pre-commit hooks, CI workflow, gitignore, and project docs.
>
> If you specifically want them as **two completely independent projects** (separate installs, no shared imports — easier to split into separate repos later), say so now. Otherwise reply "ok" or hit enter.

**Node + Python fullstack:**

> Going with **two independent projects under one repo** — `frontend/` (Node) and `backend/` (Python) keep their own dependencies, install commands, and configs. The repo root holds the shared stuff: pre-commit hooks (catches lint + format errors on both sides before commit), CI workflow, gitignore, and project docs.
>
> Reply "ok" or hit enter to proceed.

(No alternative offered — workspaces literally can't help when one side is Python.)

### 6. Staging branch

Ask:

> Want a "staging" branch before production?
>
> A staging branch is like a dress rehearsal — code goes there first, deploys to a separate copy of your site only you can see, and you click around to make sure nothing's broken before it goes live to real users. If you're solo or just starting out, you can skip this and add it later.
>
> - `yes` — set up a `stage` branch with its own protected workflow (lifecycle becomes feature → develop → stage → main)
> - `no` — go straight from develop → production (default)

### 7. GitHub repo

Ask:

> Public or private repo?
>
> - **Public** — anyone on the internet can see the code (still need permission to *change* it). Free GitHub plan includes branch protection.
> - **Private** — only people you invite can see it. Branch protection requires GitHub Pro (~$4/mo) or making the repo public.

Then verify gh auth and account plan **up front**:

```bash
gh auth status
gh api user --jq .plan.name 2>/dev/null
```

If the user picked private and is on free tier, **warn now, not later**:

> Heads up — your account is on the free tier, so branch protection won't apply to a private repo. The local pre-commit hooks and CLAUDE.md git rules still protect you, and CI still runs on PRs (you'll just *be able* to merge a failing PR if you ignore the red X). Want to make it public instead, or proceed?

### 8. Show summary, halt for confirmation

Render the plan as a fenced code block with emoji-prefixed group headers (not a markdown bullet section). Show only choices made for *this* user's project. End with: *"Reply 'yes' / 'go' / 'looks good' to proceed, or tell me what to change."*

See `references/step-08-summary-template.md` for the layout and rules.

### 9. **HALT — REAL CONFIRMATION GATE**

This is its own dedicated step. **Do not proceed under any circumstances** until the user replies with explicit affirmative confirmation (e.g. "yes", "go", "proceed", "looks good", "ok").

If running in Claude Code with auto-mode enabled, **still halt here** by using a real pausing primitive — ask the user with a question that requires a response, not just instruction text. The user must consciously approve the destructive steps that follow (creating a GitHub repo, applying branch protection, running git commands).

If the user says anything other than affirmative confirmation, ask what they'd like to change and loop back to the relevant step.

---

## Execution

Once confirmed, proceed through these steps without further halts (unless something fails).

### 10. Create directory + base files

`mkdir -p <parent>/<name>`, `cd` in. **For Next.js projects, run `create-next-app` FIRST with `--skip-git`** — see `references/configs/nextjs.md` for the exact flags and post-scaffold cleanup (delete the stub `CLAUDE.md`, keep `AGENTS.md`).

Write to repo root:
- `CLAUDE.md` — owned by `/claude-md-init`; see its `references/templates.md`. The template includes an `@.claude/rules/git-workflow.md` reference so any Claude session on the project loads the workflow rules automatically.
- `docs/architecture.html` — starter living system map, owned by `/architecture-doc-init`; write verbatim from its `references/architecture-doc-template.md` (a dependency-free, GitHub-dark HTML file: inline-SVG data-flow diagram, failure-modes table, key-files list — all shipped as clearly-marked `«placeholder»` slots). Substitute `«PROJECT_NAME»`, `«REPO»`, and `«DATE»`; leave the rest for the user to fill in as the system takes shape. (For *existing* repos, `/architecture-doc-init` fills it in from the real codebase instead.) The generated CLAUDE.md's Project map points at it (see `/claude-md-init`'s `references/templates.md`).
- `.gitignore` — see `references/gitignores.md`
- `README.md` — minimal: `# <project-name>` + one-line description placeholder
- `.editorconfig` — see `references/configs/editorconfig.md`
- `.pre-commit-config.yaml` — owned by `/precommit-init`; see its `references/precommit-config.md`
- `.claude/rules/git-workflow.md` — per-repo workflow rules (worktree usage, branch off `develop`, refspec push pattern, draft PRs, release-please flow). Verbatim copy of the template content in `references/configs/git-workflow-rule.md`. The whole skill assumes this workflow; scaffolding the rule into the repo makes it discoverable to anyone (or any Claude session) working on the project later, without requiring global agent memory.

For fullstack: create `frontend/` and `backend/` subdirs. For Python: create `<package_name>/__init__.py` and (if FastAPI) `<package_name>/main.py` — see `references/configs/python-fastapi.md`. For TS without Next.js: stub `src/index.ts` (Node) or `src/main.tsx` (Vite) so `tsc --noEmit` has something to check.

**After writing all configs, run `npx prettier --write .` once** so create-next-app's `eslint.config.mjs` and other unformatted files don't trip CI's `format:check` on first push.

### 11. Stack-specific config files

All templates are in `references/configs/`. Pick by stack:

| Stack | Files to write | Reference |
|---|---|---|
| Next.js | `package.json`, `tsconfig.json`, `eslint.config.mjs`, `.prettierrc`, `.prettierignore`, `next.config.ts` | `configs/nextjs.md` |
| Node backend (Fastify) | `package.json`, `tsconfig.json`, `eslint.config.js`, `.prettierrc` | `configs/nodejs-backend.md` |
| Python backend (FastAPI) | `pyproject.toml`, `.python-version` | `configs/python-fastapi.md` |
| Fullstack | Per-side configs in `frontend/` + `backend/` *plus* root coordination layer (root `package.json`, root pre-commit, root `.gitignore`) | both refs above |
| Research | `pyproject.toml` (ruff + jupyter only), `.python-version` | `configs/python-fastapi.md` (lighter variant) |
| Database (if chosen at Step 4) | `drizzle.config.ts`, `src/db/index.ts`, `src/db/schema.ts`, `.env.example` `DATABASE_URL`, `db:*` scripts | `configs/database-drizzle.md` |
| Auth (if chosen at Step 4) | `src/lib/auth.ts`, `src/app/api/auth/[...all]/route.ts`, `src/lib/auth-client.ts`, generated `src/db/auth-schema.ts`, `.env.example` `BETTER_AUTH_*` | `configs/auth-better-auth.md` |

**Install framework deps for real** — don't reference a tool in scripts without `npm install` / `pip install` first. Each reference doc lists its install commands.

If a database was chosen, run `npm run db:generate` (and the auth CLI generate first, if auth was chosen) so an initial migration exists in `drizzle/` before the first commit. Don't run `db:migrate` during scaffold — there's no live `DATABASE_URL` yet; it runs on first deploy via the `buildCommand`.

**Monorepo gotcha:** ESLint's flat config resolves from CWD. If `eslint.config.mjs` lives in `frontend/`, pre-commit hooks must `cd frontend` first. Handled by `/precommit-init`'s `references/precommit-config.md`.

### 12. Root-level command runner

So users can run lint/test/build from one place without Make (which isn't cross-platform). The canonical command is **`check:all`** — runs everything CI would run.

- **Any project with Node:** root `package.json` with proxying scripts. See `references/configs/root-package-scripts.md` for the full template per stack.
- **Python-only:** scaffold `scripts/dev.py` instead. See `references/configs/python-dev-script.md`.

### 13. Pre-commit hooks (single unified system at root)

Owned by `/precommit-init`. Install `pip install pre-commit` and write the per-stack `.pre-commit-config.yaml` from its `references/precommit-config.md` — but **stop before `pre-commit install`** in this flow because `.git/` doesn't exist yet (Step 15 handles activation after `git init`).

The config dispatches by file pattern: staging only Python files runs only Python hooks, staging only TS files runs only TS hooks, mixing runs both. All from root.

### 14. Tests + GitHub Actions (delegate to sister skills)

Run `/testing-init`'s execution phase, then `/gh-actions-init`'s. Treat the stack as already-known and skip their detection + summary-halt gates (project-scaffold's Step 9 covered those).

See `references/step-14-delegate.md` for what each sister skill owns, the manifest-version invariant, and the full sub-skill protocol.

### 15. Git init with main + develop (+ optional stage)

Initialize git, **verify the release-please manifest invariant** (`package.json` / `pyproject.toml` / `.release-please-manifest.json` all read `0.1.0` — abort if any differ; `0.1.0` not `0.0.0`, to dodge release-please's `1.0.0` first-release bootstrap — see `references/step-15-git-init.md`), activate pre-commit hooks (deferred from Step 13 since `pre-commit install` needs `.git/` to exist), apply auto-fixers to the working tree, then commit so the initial commit lands clean. Without the pre-commit pass, every scaffold ships with a no-op fixup PR for trailing newlines and prettier nits — generators like `create-next-app` produce files that don't satisfy the hooks, and the bootstrap-exception contract (Step 17) prevents pushing those fixes directly to `develop`. The version check catches missed resets in 5 seconds rather than at the first release attempt. Create `main` + `develop` (+ `stage` if opted in) and check out `develop`.

See `references/step-15-git-init.md` for the bash sequence and the version-invariant check.

### 16. Detect pre-push protection before pushing

Before Step 17 pushes to `main`/`develop`, check whether anything will block direct pushes to protected branches. Check **all four** common sources, not just `core.hooksPath`:

1. `git config --global core.hooksPath` (git's own hook directory)
2. Claude harness hooks at `~/.claude/hooks/*.{py,sh}` (these run *before* git sees the push)
3. Shell aliases/functions shadowing `git`
4. `git config --global init.templateDir` (template applied to fresh `git init`)

If any source produces a hit, surface the verbatim warning that frames this as the skill's **documented bootstrap exception** (not a violation of the user's global rules) and ask about override env var conventions before attempting the push. Surfacing this *before* Step 17 keeps the bootstrap atomic.

See `references/step-16-prepush-hooks.md` for the detection commands and the verbatim warning message.

### 17. Create GitHub repo and push (bracketed by auto-mode halts)

Create the remote with `gh repo create`, flip on the repo-level setting that lets GitHub Actions create + approve PRs (otherwise release-please and any other PR-creating workflow fails on first run with the `createPullRequest` GraphQL error), then push `main`, `develop`, and (if opted in) `stage` using the override env var Step 16 confirmed. **This is the only step in the entire skill that pushes directly to protected branches** — the exception is push-only, scoped to seeding the remote, and never extends to subsequent operations.

The push is bracketed by two **real halts** (not text-only notes — text mid-flow gets skipped past):

- **17a — PRE-PUSH GATE.** Surface a verbatim message telling the user that Claude Code's auto-mode classifier will block the bootstrap push without surfacing an approval dialog, and to toggle auto-mode OFF before replying `go`.
- **17b — Push.** Run the `gh repo create` + `gh api … actions/permissions/workflow` + `git push` sequence, then surface the **`RELEASE_PLEASE_TOKEN` secret callout** — every new repo needs this PAT-backed secret (`gh secret set RELEASE_PLEASE_TOKEN`) or the release-please and develop→main workflows fail on first run. User action; don't ask for the PAT value in chat.
- **17c — POST-PUSH GATE.** Surface a verbatim message that the bootstrap exception is done and the user can toggle auto-mode back ON. Wait for `continue` before proceeding to Step 18.

See `references/step-17-create-repo-push.md` for the bash sequence, the verbatim gate messages, and the full bootstrap-exception contract.

### 18. Branch protection (skip if free-tier private)

Skip entirely if Step 7 showed free-tier + private repo. Otherwise apply protection to `main`, `develop`, and (if staging enabled) `stage`, requiring the CI status checks to pass.

Owned by `/gitflow-init`. See its `references/branch-protection.md` for the bash function and the 403-fallback message.

### 19. Set develop as default branch

`gh repo edit --default-branch develop` — PRs default to merging into `develop`; `main` only gets touched by release-please's release PRs.

Owned by `/gitflow-init` (Step 7 of its standalone flow).

### 20. Smoke test (verify the scaffold actually works)

Before declaring success, run the full smoke sequence from the project root: install deps → lint → typecheck → `pre-commit run --all-files` → test → build → `check:all`. **Don't use empty commits** — invoke hooks directly so there's no commit cleanup needed.

If any step fails, report the specific failure and offer to fix. See `references/step-20-smoke-test.md` for the full bash sequence and common failure modes.

### 21. Report back

Print a status block (local path, GitHub URL, current branch, files created, branch protection status, smoke test results) followed by the verbatim "Next steps" + "Useful commands" block.

See `references/step-21-report-template.md` for the exact template.

---

## The full lifecycle

This is what the scaffold enables out of the box:

1. **Start a new feature** — make a new branch off `develop`, name it something like `feat/dark-mode`. Work on it locally.
2. **Commit your changes** — pre-commit hooks check your code as you commit. Bad code doesn't even get committed.
3. **Open a Pull Request** — push your branch to GitHub and open a PR targeting `develop`. CI runs every check (`checks`, e2e, build — plus integration if you scoped it in). The PR can't merge until they're all green.
4. **Merge to develop** — once CI is green and you're happy, merge. Your code is now on `develop`.
5. **Time to release** (skipping `stage` if not enabled, otherwise `develop` → `stage` → `main`) — open a PR from `develop` → `main`. Same checks run.
6. **Release-please takes over** — once merged to `main`, release-please opens a "release PR" with a changelog and a version bump (decided by your commit messages). You review it, merge it.
7. **Tag + deploy** — release-please tags the commit (e.g. `v1.4.0`), creates a GitHub Release, and the deploy workflow kicks off automatically.

---

## Why these defaults (one-line each)

- **Lean `CLAUDE.md`** (50–120 lines): bloat weakens the whole file
- **`main` + `develop` (+ optional `stage`)**: PRs target `develop`, `main` release-only
- **Branch protection on all release branches**: hard stops, not soft rules
- **Pre-commit at root, polyglot**: faster feedback, lower CI cost, one config for fullstack
- **Consolidated CI pipeline** (`checks` = lint + typecheck + unit, plus e2e and build): matches a standard production pipeline; the fast checks share one job and `build` gates on them
- **Release-please + conventional commits**: removes manual versioning
- **Deploy stub**: targets vary too much to ship a real implementation
- **Private by default**: easier to flip to public later than the reverse
- **Next.js for frontend / FastAPI for Python BE**: opinionated batteries-included defaults
- **`check:all` as the "run everything" command**: cross-platform, no Make required

## Toolchain non-goals (settled — do not drift)

These are decided. Do **not** introduce them on a scaffolded project, even when asked to "match" an existing repo — older hand-built repos that used them predate this skill and are not precedents.

- **No Make / justfile / taskfile.** Canonical commands run through npm — `npm <command>` / `npm run <command>` (e.g. `npm run check:all`, `npm run lint`, `npm run db:migrate`): cross-platform and discoverable via `npm run`. (Python-only repos with no npm use `scripts/dev.py`.) Don't wrap npm scripts in a Makefile — that's the inverse of the user's "expose tools as npm scripts" preference.
- **No Biome.** ESLint (flat config) + Prettier are canonical for JS/TS lint + format. Biome is a JS/TS-only ESLint+Prettier replacement — it is **not** a polyglot or Python tool, so it solves nothing the defaults don't already cover.
- **Ruff is canonical for Python** lint + format (Biome has no Python support). This is the Python analog people sometimes confuse Biome for.

## Reference files

### Owned by this skill

- `references/sister-skills-dependency.md` — what Step 1 checks for and why
- `references/step-14-delegate.md` — delegation order, sub-skill responsibilities, manifest-version invariant, sub-skill protocol
- `references/step-15-git-init.md` — git init + branch creation + pre-commit activation sequence
- `references/step-16-prepush-hooks.md` — global pre-push hook detection + warning message
- `references/step-17-create-repo-push.md` — `gh repo create` + bootstrap push sequence + bootstrap-exception contract
- `references/gitignores.md` — `.gitignore` per stack
- `references/step-08-summary-template.md` — emoji-grouped pre-execution summary
- `references/step-20-smoke-test.md` — full smoke sequence + failure-mode cheatsheet
- `references/step-21-report-template.md` — verbatim final report + "Next steps" block
- `references/configs/` — per-stack bootstrap config templates
  - `editorconfig.md`, `nextjs.md`, `nodejs-backend.md`, `python-fastapi.md`
  - `node-ts.md` — shared Node/TS configs (Prettier, `.prettierignore`, ESLint notes) used by the Next.js and Fastify configs
  - `root-package-scripts.md`, `python-dev-script.md`
  - `git-workflow-rule.md` — template for the per-repo `.claude/rules/git-workflow.md` Step 10 scaffolds
  - `styling-css-modules.md` — CSS-Modules styling convention (Step 4 default) + how the other styling choices wire up
  - `database-drizzle.md` — opt-in Drizzle + Postgres setup (Step 4 DB question): client, migrations, `db:*` scripts, per-host connection strings
  - `auth-better-auth.md` — opt-in auth (Step 4, DB-gated): Better Auth default + Auth.js alternative, adapter wiring, schema-via-Drizzle
- `references/explainers/concepts.md` — plain-English concept explainers

### Owned by sister skills

- **`/testing-init`** (Step 14) — test runners + configs + smoke stubs + test scripts + test jobs in `ci.yml`. Templates: `skills/testing-init/references/{runners,test-stubs,scripts,ci-test-job}.md`.
- **`/gh-actions-init`** (Step 14) — CI structural jobs + release-please + release verification + deploy stub. Templates: `skills/gh-actions-init/references/{detection,ci-structure,release-please,release-verification,deploy-stub}.md`.
- **`/gitflow-init`** (Steps 18 + 19) — branch protection + default-branch setting (+ develop/stage creation for retrofit). Templates: `skills/gitflow-init/references/branch-protection.md`.
- **`/precommit-init`** (Step 13) — pre-commit at root, polyglot (Python / Node / fullstack). Templates: `skills/precommit-init/references/precommit-config.md`.
- **`/claude-md-init`** (Step 10) — per-stack CLAUDE.md templates. Templates: `skills/claude-md-init/references/templates.md`.
- **`/architecture-doc-init`** (Step 10) — the `docs/architecture.html` system-map template + coordinate-grid editing guide (blank for new repos here; that skill fills it in for existing repos). Templates: `skills/architecture-doc-init/references/architecture-doc-template.md`.

## When NOT to use this skill

- User wants to add CLAUDE.md to an *existing* repo — just edit the file, no scaffolding
- User is doing a one-off prototype with no GitHub intent — skip gh + protection steps
- User explicitly says they don't want `develop` — fall back to `main`-only
- User explicitly says they don't want CI yet — skip workflow creation, leave the rest

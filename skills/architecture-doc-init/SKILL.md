---
name: architecture-doc-init
description: Add a docs/architecture.html living system map to an existing repo — explores the codebase (entrypoints, data flow, CI/deploy wiring) and known failure modes (fix commits, closed bugs, CLAUDE.md gotchas), then writes a self-contained, dependency-free HTML architecture doc with an inline-SVG data-flow diagram, failure-modes table, and key-files list, filled in with the repo's real components. Use when the user wants to "add an architecture doc", "add a system map", "visualize the architecture", "add docs/architecture.html", or otherwise bring a visual architecture doc to a repo that doesn't have one. Detects an existing docs/architecture.html and won't overwrite without consent. New repos get the blank template automatically via /project-scaffold.
---

# architecture-doc-init

Retrofits a `docs/architecture.html` **living system map** onto an existing repo: one
self-contained HTML file (no build step, no CDN, no JS framework — plain CSS, never Tailwind)
containing an inline-SVG data-flow diagram, a known-failure-modes table, a key-files list, a
legend, and an "operate it" note box.

Unlike `/project-scaffold` (which drops the blank fill-in template into brand-new repos, Step 10),
this skill **fills the template in** — it maps the repo's *real* components, flows, and failure
history, so the doc is useful the moment it lands.

The template itself (HTML + coordinate-grid editing guide) lives in
`references/architecture-doc-template.md`. This skill owns it; `/project-scaffold` Step 10
references it.

## When to trigger

User says any of:
- "add an architecture doc / architecture diagram"
- "add a system map / visual map of this repo"
- "visualize the architecture"
- "add docs/architecture.html"

## When NOT to use

- Brand-new repo being scaffolded → `/project-scaffold` already writes the blank template
- User wants prose architecture docs (ADRs, design docs) — this skill produces the single-file
  visual map, not a docs site

---

## Flow

### 1. Idempotency check

If `docs/architecture.html` already exists, **stop and ask**: overwrite, update in place
(preserve their filled-in content, refresh structure), or abort. Never silently replace it —
by design it accumulates hand-maintained knowledge.

### 2. Explore the codebase

Build the component inventory from the repo itself (read, don't ask):

- **Entrypoints** — `package.json` scripts/`main`, `pyproject.toml`, framework conventions
  (`src/app/`, `<package>/main.py`), CLI entries, cron/scheduler scripts
- **Core modules** — the engine: business logic, services, pipelines
- **Data layer** — db clients/schema (`src/db/`, Drizzle/ORM configs), storage, caches
- **Inputs** — HTTP routes, queues, webhooks, scheduled triggers, file drops
- **Outputs & alerts** — responses, writes, notifications, logging/observability
- **Guards** — auth, validation, rate limits, env/dependency preconditions
- **Deploy model** — `.github/workflows/`, `render.yaml`/platform configs, `.env.example`.
  Determine **what actually triggers a production deploy**, and say so exactly — this is the
  operational fact newcomers get wrong most often. Check whether the platform config disables
  branch auto-deploy (`autoDeploy: false` or equivalent) and whether the deploy is driven from
  CI after a tag is cut (grep `.github/workflows/release-please.yml` for a deploy step). If so
  the repo is on the **tagged-only** model — record that production runs the exact tagged
  commit and that the untagged promotion merge doesn't deploy, rather than the vaguer "deploys
  from `main`". Background: `gh-actions-init/references/tagged-deploy.md`.

`CLAUDE.md` and `README.md` usually name the load-bearing pieces — read them first.

### 3. Mine real failure modes

The failure-modes table is the doc's highest-value section — populate it with history, not
hypotheticals:

- `git log --grep 'fix' --grep 'revert'` — recurring subjects = real failure modes
- Closed bug-labeled issues (`gh issue list --state closed --label bug`)
- `CHANGELOG.md` fix entries; gotcha/warning lines in `CLAUDE.md`

Aim for 3–6 rows (symptom / root cause / fix / status). If the repo has no such history yet,
keep 1–2 `«placeholder»` rows so the section survives as a prompt to fill later.

### 4. Fill the template

Write `docs/architecture.html` from `references/architecture-doc-template.md`:

- Substitute `«PROJECT_NAME»`, `«REPO»`, `«DATE»` (today, YYYY-MM-DD)
- Replace placeholder nodes/rows/paths with the real components from Steps 2–3, following the
  template's coordinate-grid convention (documented in the `GRID` comment inside the SVG —
  keep it so the file stays hand-editable)
- Grow the diagram as needed (more pipeline steps, inputs, alert entries) using the editing
  guide; keep lane semantics: inputs = blue, guards = amber, engine = green, alerts = purple,
  failure paths = dashed red
- A `«placeholder»` may remain **only** where the codebase genuinely doesn't answer the
  question (e.g. an empty failure-modes history) — never as a shortcut

### 5. Verify

Open the file in a browser (or render-check it) before declaring done: tags balanced, no SVG
text overflowing its box/lane, diagram legible. Fix overflows by shortening labels or widening
per the grid math.

### 6. CLAUDE.md pointer

If the repo has a `CLAUDE.md`, add the Project-map bullet per `/claude-md-init`'s convention
(see its `references/templates.md`, "Architecture-doc reference"):

```markdown
- `docs/architecture.html` — living system map (open in a browser). Update it when components, flows, or failure modes change.
```

If there's no `CLAUDE.md`, mention `/claude-md-init` and move on — don't scaffold one uninvited.

### 7. Report

Show the file path, the components mapped (count of nodes/flows/failure rows), and remind:
this is a **living doc** — update it alongside changes to the components it maps. Commit via
the repo's normal workflow (feature branch + PR if the repo uses one).

---

## Reference files

- `references/architecture-doc-template.md` — the fill-in HTML template + coordinate-grid
  editing guide. Owned by this skill; `/project-scaffold` Step 10 writes it verbatim (blank)
  for new repos.

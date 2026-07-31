# CI structure jobs (lint + typecheck + format:check + build)

The structural CI jobs that compose with `testing-init`'s test jobs to form the full 5-check pipeline. This skill writes only the *non-test* jobs.

## Node / TypeScript

`.github/workflows/ci.yml` — minimal version when no existing CI exists:

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]   # adjust per branch detection
  push:
    branches: [main]            # NOT develop — see note below
  workflow_dispatch:            # manual "rebuild now" + dispatch target for /rebuild

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-typecheck:
    name: lint + typecheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22       # adjust if package.json pins engines.node
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run format:check   # only if format:check exists in package.json
      - run: npm run typecheck

  build:
    name: production build
    runs-on: ubuntu-latest
    needs: [lint-typecheck]
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v7
        with:
          name: build-output
          path: |
            .next/
            dist/
            build/
            out/
          retention-days: 7
          if-no-files-found: ignore
```

Notes:
- **`push` is `[main]` only, deliberately — not `develop`.** Every commit reaches
  `develop` through a PR, which already runs the full suite via the `pull_request`
  trigger. Re-running CI on the post-merge `push` to `develop` just re-tests code that
  already passed — pure duplicate Actions minutes. `push: main` stays as a cheap
  belt-and-suspenders re-check on the develop→main landing before a release. If the repo
  has extra long-lived integration branches (e.g. `integration/**`), add those to the
  `push` list too; never add `develop`. See `ci-cost-migration.md` for the measurement
  behind this and how to retrofit an existing repo.
- `concurrency` cancels stale runs on the same PR.
- `build` depends on `lint-typecheck` so a broken lint doesn't waste build time.
- `if-no-files-found: ignore` on the artifact handles different framework outputs (Next → `.next/`, Vite → `dist/`, etc.).
- Skip `format:check` step if `prettier` isn't in dev deps or no `format:check` script exists.

## Python

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]            # NOT develop — same rationale as the Node CI above
  workflow_dispatch:            # manual "rebuild now" + dispatch target for /rebuild

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
        with:
          python-version: '3.12'
      - run: pip install -e ".[dev]"
      - run: ruff check .
      - run: ruff format --check .

  typecheck:
    name: typecheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
        with:
          python-version: '3.12'
      - run: pip install -e ".[dev]"
      - run: mypy .
```

Notes:
- No `build` job — Python apps deploy source.
- Skip `typecheck` job if `mypy` isn't in dev deps.
- For uv-managed projects, replace `pip install -e ".[dev]"` with `uv sync`.

## Fullstack (Node frontend + Python backend)

Two strategies:

**a. Single workflow, no path filters** — both sides run on every push. Simple, slower.
**b. Path-filtered jobs** — frontend jobs only run if `frontend/**` changed, etc. Faster, more complex YAML.

Default to (a) for clarity. Surface (b) as an option if the user mentions slow CI.

```yaml
jobs:
  frontend-lint-typecheck:
    name: frontend lint + typecheck
    # ... Node steps, but:
    # - run: npm --prefix frontend ci
    # - run: npm --prefix frontend run lint
    # ...

  backend-lint-typecheck:
    name: backend lint + typecheck
    # ... Python steps, but operating in backend/

  build:
    name: production build
    needs: [frontend-lint-typecheck, backend-lint-typecheck]
    # ... build the side that needs it
```

## What belongs in the consolidated `checks` job vs its own job

Once a repo consolidates its fast checks into a single `checks` job (see the job-consolidation note in `ci-cost-migration.md`), every *new* check faces the same routing question. The deciding factor is **not** "is it similar in nature to the others" — it's **setup reuse and duration**, because of two billing facts: GitHub bills each job's wall-clock **rounded up to the whole minute**, and every separate job re-runs `checkout` + `npm ci` (the expensive part, ~30–60s).

**Fold it into `checks`** when the check:
- reuses the setup `checks` already did (checkout + `npm ci`, same toolchain), **and**
- is fast — seconds of work: lint, typecheck, `format:check`, actionlint, dependency audit, other static analysis.

Serializing several fast steps behind one `npm ci` costs a few seconds of wall-clock; splitting them into parallel jobs costs a fresh `npm ci` **and** a rounded-up minute *each*. For fast, setup-sharing checks, folding is strictly cheaper and barely slower.

**Give it its own parallel job** when the check:
- needs a **different environment** — another language toolchain, service containers, a build matrix, a different OS — so it can't share `checks`' setup anyway; **or**
- is **long AND independent** (e2e, production build, a heavy integration suite). Here the separate rounded-up minute is earned back by running concurrently instead of serially — which is exactly why `e2e` and `build` stay their own jobs.

Two mechanics that drive the rule:
- Steps within a job run **sequentially** (there is no in-job parallelism); separate jobs run **concurrently**. So the one real risk of an over-stuffed `checks` is that a *slow* step makes `checks` the long pole against the parallel jobs. The guard is **duration, not kind** — keep `checks` the fast fail-first gate, and split a step out only once it grows long. Never split the fast ones.
- Order steps fastest-and-most-likely-to-fail first (e.g. run actionlint *before* `npm ci`) so a bad change fails in seconds before the expensive steps run. A `build` job with `needs: [checks]` is then skipped too.

## Extend-mode rules

When `ci.yml` already exists (e.g., `testing-init` ran first):

1. **Read the existing file** — preserve indentation style, top-level keys, comments.
2. **Identify existing job names** via `yq '.jobs | keys' .github/workflows/ci.yml` or grep fallback.
3. **For each new job**, check if `name:` already appears (in the YAML `name:` value, NOT the YAML key — the value is what shows up as the GH Actions check name). Skip if present.
4. **Don't change `on:` triggers** in an existing workflow — surface a warning, don't auto-fix. Two things to check, and note they point in opposite directions:
   - **`pull_request`** should include every branch that receives PRs (`main` + `develop`). If `develop` is missing there, PRs into develop run no CI — flag it.
   - **`push`** should be `[main]` only (plus any long-lived integration branches). `push` including `develop` is the *duplicate-minutes* smell, not a gap — flag it for removal, don't treat `[main]`-only push as stale.
5. **Match indentation** — read the first job in the file and match its leading-spaces level (typically 2 or 4).
6. **Append new jobs at the end** of the `jobs:` block, separated by a blank line.

If the existing `ci.yml` is structured very differently (e.g., uses reusable workflows, matrix strategies, etc.) and your simple append would conflict: **stop and ask**. Don't try to be clever.

## Job-name → branch-protection-context mapping

Each job's `name:` field is what GitHub branch protection uses as a "required status check context." The job names this skill writes match what `project-scaffold`'s branch protection script expects:

- `lint + typecheck`
- `production build`
- (Tests come from `testing-init`: `unit tests`, `integration tests`, `e2e tests`)

Don't rename these without also updating any branch protection contexts, or protection silently breaks (the new check is required but the new job isn't producing it).

**Caveat — this only bites if the repo actually has required status checks.** Required
checks come from branch protection, which is unavailable on free-tier private repos
(the API returns 403 "Upgrade to GitHub Pro"). On such a repo there are no contexts to
break, so a job rename is a no-op. Check the repo's plan/visibility before warning about
a rename. Branch protection is owned by `gitflow-init` — see its
`references/branch-protection.md` for the availability check and the 403-fallback
message; don't reproduce that logic here.

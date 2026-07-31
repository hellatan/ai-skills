# Optional CI test job

Only invoked if the user opted in at flow Step 4.

**Ownership split.** `testing-init` owns the test *steps/commands*; it does **not** own the
`checks` job skeleton — that belongs to `gh-actions-init`
(`gh-actions-init/references/ci-structure.md`). Concretely:

- **Unit tests** are a *step folded into the `checks` job* — they reuse that job's checkout
  + `npm ci` (or `pip install`) instead of paying for a separate `unit` job. This is the
  consolidation: lint + typecheck + unit run in one job.
- **Integration** and **e2e** stay their *own jobs* — they need services / a browser, so
  they don't belong in the fast `checks` job.

**Extend, don't replace.** Detect existing jobs first so you never stomp what
`gh-actions-init` wrote:

```bash
existing_jobs=$(yq '.jobs | keys' .github/workflows/ci.yml 2>/dev/null || echo "")
```

(If `yq` isn't installed, just read the file and grep.)

## Unit tests → a step in the `checks` job (always)

Unit tests are **not a job**. Which case you're in depends on whether a `checks` job
already exists:

### Case A — a `checks` job already exists

(`gh-actions-init` ran first, or a prior `testing-init` run seeded it.) Append the
unit-test step at the `# --- testing-init insertion point ---` comment `gh-actions-init`
left — or, if that comment was stripped by a formatter/edit, after the last existing step
in `checks`. Keep unit **last** (cheap lint/typecheck fail first). Do **not** create a
`unit` job.

Node — append to the existing `checks` job's steps:
```yaml
      - run: npm run test:unit
```

Python — append to the existing `checks` job's steps:
```yaml
      - run: pytest -m "not integration and not e2e"
```

### Case B — no `checks` job yet

(`testing-init` is running before `gh-actions-init`, or standalone.) Create the `checks`
job yourself, holding just the unit-test step, and leave the insertion-point comment
*above* it so `gh-actions-init` later prepends lint → format:check → typecheck ahead of
unit (unit stays last).

Node:
```yaml
  checks:
    name: checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      # --- gh-actions-init prepends lint → format:check → typecheck above this step ---
      - run: npm run test:unit
```

Python:
```yaml
  checks:
    name: checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
        with:
          python-version: '3.12'
      - run: pip install -e ".[dev]"
      # --- gh-actions-init prepends ruff check → ruff format --check → mypy above this step ---
      - run: pytest -m "not integration and not e2e"
```

Either way the end state is a single `checks` job whose last step is the unit tests.

## Integration (if scoped in)

```yaml
  integration:
    name: integration tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run test:integration
```

Python equivalent: `pytest -m integration`.

## E2E (if scoped in, Node only)

```yaml
  e2e:
    name: e2e tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      # Cache the browser binaries (~100MB+) across runs, keyed on the lockfile so the
      # cache busts when the pinned Playwright version changes. On a hit we skip the
      # download and only apt-install the OS deps (those aren't cacheable — they're
      # system packages, not files under the cached path).
      - name: Cache Playwright browsers
        id: playwright-cache
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: ${{ runner.os }}-playwright-${{ hashFiles('**/package-lock.json') }}
      - if: steps.playwright-cache.outputs.cache-hit == 'true'
        run: npx playwright install-deps
      - if: steps.playwright-cache.outputs.cache-hit != 'true'
        run: npx playwright install --with-deps
      - run: npm run test:e2e
```

Notes:
- **The cache is the cost lever in this job.** Downloading browsers on every run is
  1–2 min of billed time that a cache hit removes. Don't drop the two conditional
  install steps down to a single `npx playwright install --with-deps` — that
  re-downloads even on a hit.
- `install-deps` (hit) installs only the OS packages; `install --with-deps` (miss)
  fetches browsers *and* OS packages.
- Narrow to one browser (`... install --with-deps chromium`, and likewise for
  `install-deps chromium`) if the Playwright config only projects Chromium — smaller
  cache, faster miss path.
- Key on `package-lock.json` (or the lockfile the project actually uses — `yarn.lock`,
  `pnpm-lock.yaml`). Keying on nothing means a stale cache after a Playwright bump;
  keying on the whole repo means a needless miss on every commit.

## No `.github/workflows/ci.yml` yet

Create a minimal one containing the `checks` job (Case B above — the unit-test step, with
the insertion-point comment above it) plus any integration/e2e jobs the user chose. Don't
add lint/format:check/typecheck steps or a `build` job — those are `gh-actions-init`'s; it
folds its steps into `checks` and adds `build` when it runs later.

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]            # NOT develop — a PR already runs CI before merge; a
                                # post-merge push run on develop just re-tests passing
                                # code. Matches gh-actions-init/references/ci-structure.md.

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # checks (holding the unit-test step, Case B) + any integration/e2e jobs opted into
```

## Top-of-file conventions

- `concurrency.cancel-in-progress: true` — cancels stale runs when new commits push to the same PR.
- `cache: npm` — speeds up Node installs by ~10s.
- `node-version: 22` — current LTS at scaffold time. Update if the project pins a different version in `engines.node` or `.nvmrc`.

## Match existing branch names

If the repo uses `master` or some other default branch instead of `main`, use that in the `on.push.branches` / `on.pull_request.branches` arrays. Detect with:

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
```

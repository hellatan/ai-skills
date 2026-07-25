# Optional CI test job

Only invoked if the user opted in at flow Step 4. Two paths:

## Path 1: `.github/workflows/ci.yml` already exists

**Extend it, don't replace.** Add the test jobs, preserving any existing jobs (lint, build, etc.). Detect existing jobs by name first:

```bash
existing_jobs=$(yq '.jobs | keys' .github/workflows/ci.yml 2>/dev/null || echo "")
```

(If `yq` isn't installed, just read the file and grep.)

For each scope the user chose, add the matching job *if it doesn't already exist*:

### Unit (always)

```yaml
  unit:
    name: unit tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6   # for Node projects
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run test:unit
```

For Python:
```yaml
  unit:
    name: unit tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v6
        with:
          python-version: '3.12'
      - run: pip install -e ".[dev]"
      - run: pytest -m "not integration and not e2e"
```

### Integration (if scoped in)

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

### E2E (if scoped in, Node only)

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

## Path 2: No `.github/workflows/ci.yml` yet

Create a minimal one with just the test jobs the user chose. Don't include lint/typecheck/build — those belong to `gh-actions-init` (which can extend this CI later).

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
  # ... only the test jobs the user opted into
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

# Deploy stub

Platform-agnostic. User fills in the actual deploy step.

## ⚠️ Read `references/tagged-deploy.md` first

The **default** deploy model this skill scaffolds does **not** use this standalone `deploy.yml`. It puts the deploy step inside `release-please.yml`, in the same job that cuts the tag, gated on the tag being verified on the remote. That file is the canonical design; this one is the fallback for cases that genuinely need a separate workflow.

Two reasons the folded-in version is the default:

1. **A tag pushed with `GITHUB_TOKEN` does not fire `on: push: tags`.** GitHub's recursion guard suppresses it. A `deploy.yml` wired exactly as below will simply never run in that setup — green pipeline, nothing deployed. It works only when the tag is pushed with a PAT (`RELEASE_PLEASE_TOKEN`), which is the case for repos scaffolded by this skill — but it is a live tripwire the moment someone "simplifies" the token config.
2. **A separate workflow can't see the release verification result**, so it deploys on the existence of a tag rather than on a verified release outcome.

Use this standalone `deploy.yml` when the deploy genuinely needs its own workflow: a build matrix, a GitHub `environment:` approval gate, or per-component fan-out in a multi-service monorepo. Otherwise fold the deploy into `release-please.yml`.

## Default tag pattern

Single-package release-please configs produce `v1.2.0` tags — matched by `tags: ['v*.*.*']`. A fullstack app shipped as a single unit (the single-package config applied at the repo root) uses this trigger too.

The fullstack-monorepo config in `references/release-please.md` produces **per-component** tags — `frontend-v1.2.0`, `backend-v1.2.0` — because independently-versioned packages can't share one component-less tag without stranding (see that file for the verified config and why). So a monorepo deploy needs the per-component trigger in the "Per-component releases" section below, **not** `v*.*.*`.

## Standard `deploy.yml` (prod-only, no staging)

`.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy-prod:
    name: Deploy to production
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v6

      # ─── HOW TO USE THIS FILE ───────────────────────────────────────
      # 1. Pick a deploy target from the list below and uncomment its block.
      # 2. Each platform needs you to fetch credentials from its dashboard
      #    (e.g., a service ID and API key for Render, a token for Vercel).
      # 3. Add each credential as a GitHub secret:
      #    repo → Settings → Environments → "production" → Add secret.
      #    The secret names must match the `${{ secrets.NAME }}` references
      #    in the block you uncommented.
      # 4. Replace the placeholder `echo "TODO ..."` line at the bottom with
      #    your build step (if your platform doesn't build for you).
      # 5. To trigger a deploy: push a tag like `v0.1.0` (release-please
      #    does this automatically when you merge a release PR).
      # 6. Watch the run under the "Actions" tab on GitHub. If it fails,
      #    the error usually points to a missing secret or wrong service ID.
      #
      # Not sure which platform to pick?
      # - You have a Next.js app and want zero-config: Vercel.
      # - You want fair pricing without lock-in, runs anything: Render.com.
      # - Backend services with global routing or CLI-first workflows: Fly.io.
      # - Already have a VPS/Linux box you control: SSH/rsync.
      # - Multi-service Docker setups (Kubernetes, ECS, etc.): GHCR.
      # ────────────────────────────────────────────────────────────────

      # TODO: Build step (or download from CI artifact). Example:
      # - uses: actions/setup-node@v6
      #   with:
      #     node-version: 22
      #     cache: npm
      # - run: npm ci && npm run build

      # TODO: Deploy step. Pick one and uncomment:
      #
      # Render.com:
      #   - uses: johnbeynon/render-deploy-action@v0.0.8
      #     with:
      #       service-id: ${{ secrets.RENDER_SERVICE_ID }}
      #       api-key: ${{ secrets.RENDER_API_KEY }}
      #
      # Vercel:
      #   - run: npx vercel deploy --prod --token=${{ secrets.VERCEL_TOKEN }}
      #
      # Fly.io:
      #   - uses: superfly/flyctl-actions/setup-flyctl@master
      #   - run: flyctl deploy --remote-only
      #     env:
      #       FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      #
      # Railway:
      #   - uses: bervProject/railway-deploy@main
      #     with:
      #       railway_token: ${{ secrets.RAILWAY_TOKEN }}
      #       service: ${{ secrets.RAILWAY_SERVICE_NAME }}
      #
      # Docker push to GHCR:
      #   - uses: docker/login-action@v3
      #     with:
      #       registry: ghcr.io
      #       username: ${{ github.actor }}
      #       password: ${{ secrets.GITHUB_TOKEN }}
      #   - uses: docker/build-push-action@v6
      #     with:
      #       push: true
      #       tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
      #
      # SSH/rsync to a server:
      #   - run: |
      #       echo "${{ secrets.DEPLOY_KEY }}" > deploy_key
      #       chmod 600 deploy_key
      #       rsync -avz -e "ssh -i deploy_key" dist/ user@host:/var/www/app/
      - run: echo "TODO — fill in deploy steps for production"
```

## With staging (only when the project has a `stage` branch)

Detect via `git ls-remote --heads origin stage`. **No `stage` branch means no staging environment** — that is the normal, intentional state for most repos, not a gap to fill. Don't scaffold a staging job, a staging service, or a `develop`-watching deploy for a repo that doesn't have the branch. See the "Environments" section of `references/tagged-deploy.md` for why, and for the release-please pre-release config a staging environment needs.

If `stage` *does* exist, staging is driven by **pre-release tags** (`vX.Y.Z-rc.N`) cut from `stage` — the same tagged-only discipline as production, just a different class of tag. It is **not** triggered by a push to `stage`: a branch-triggered deploy has the same "which commit is on staging?" problem that `autoDeploy` has on production.

The default remains folding both deploys into their respective release-please workflows (`release-please.yml` for prod, `release-please-stage.yml` for staging). Use the standalone variant below only for the same reasons as the prod-only stub above — build matrix, `environment:` approval gate, per-component fan-out — and remember the loop guard: these triggers only ever fire if the tags were pushed with `RELEASE_PLEASE_TOKEN`, never with `GITHUB_TOKEN`.

```yaml
name: Deploy

on:
  push:
    tags:
      # Production releases only — the `-rc` suffix makes pre-releases fail this
      # glob, which is what keeps a release candidate out of production.
      - 'v*.*.*'
      # Pre-releases cut from `stage`.
      - 'v*.*.*-rc.*'

jobs:
  deploy-staging:
    name: Deploy to staging
    if: contains(github.ref, '-rc.')
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v6
      # TODO: staging deploy steps (point at the staging service/URL).
      # The checked-out tree IS the tagged pre-release commit.
      - run: echo "TODO — fill in deploy steps for staging"

  deploy-prod:
    name: Deploy to production
    if: startsWith(github.ref, 'refs/tags/v') && !contains(github.ref, '-rc.')
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v6
      # TODO: prod deploy steps
      - run: echo "TODO — fill in deploy steps for production"
```

**The `-rc.` guard on `deploy-prod` is load-bearing.** `v*.*.*` matches `v1.2.0-rc.1` as well as `v1.2.0` — without the `!contains(...)`, every release candidate would ship straight to production, which is the exact opposite of what a staging environment is for.

## Render Blueprint (`render.yaml`) — opt-in, only when the target is Render

**Generate this only when the user's deploy target is Render.** If they're on Vercel, Fly, Railway, a VPS, or undecided, do **not** write a `render.yaml` — there's nothing to gain from a Render-specific file on a non-Render deploy. In that case ship only the platform-neutral `deploy.yml` stub above.

When Render *is* the target, a `render.yaml` Blueprint is dramatically better than dashboard clickops: it encodes the services in the repo, Render provisions them on apply, and prompts for the `sync: false` secrets. The dashboard becomes read-only state instead of the source of truth.

**First ask where Postgres is hosted** — this isn't necessarily Render. (When invoked from `/project-scaffold`, this was already answered at its Step 4 DB-host question — Neon/Render/Supabase/local — so reuse that answer instead of re-asking.) Two paths:

- **Render-managed Postgres** — declare a `databases:` block (shown below) and wire `DATABASE_URL` via `fromDatabase`. The free-vs-paid question below applies.
- **External Postgres (Neon, Supabase, a managed instance, etc.)** — do **not** declare a `databases:` block. Drop it entirely and set `DATABASE_URL` as a `sync: false` secret pointing at the external host; Render prompts for the value on apply. The free-vs-paid Postgres row below is then irrelevant (you pick the tier on Neon/Supabase, not here). This is the path when the user is on Neon.

**For Render-managed Postgres, ask whether it's a free plan or a paid plan** — it changes the `plan:` values you seed (and there is no way to infer it). Seed accordingly:

| | Free | Paid |
|---|---|---|
| web service `plan:` | `free` | `starter` (bump to `standard`+ as needed) |
| Postgres `plan:` | `free` | `basic-256mb` (smallest paid tier) |
| Caveat | Free Postgres **expires after 30 days** and free web services spin down when idle — fine for demos, not for anything that must stay up. | No expiry; charged monthly. |

`render.yaml` (Next.js + Postgres example — **paid plan** shown; swap the two `plan:` lines to `free` for a free-tier blueprint, and adjust services/env to the project):

```yaml
# Deploy model: TAGGED-ONLY. autoDeploy is OFF, so no push to `main` deploys on
# its own — not the develop→main promotion merge (untagged), not the release-PR
# merge. Production ships exactly once per release, triggered from
# .github/workflows/release-please.yml AFTER release-please cuts the vX.Y.Z tag:
# that step POSTs the deploy hook with `?ref=<tagged-sha>`, so the exact tagged
# commit is built and never an untagged one.
#
# Required repo secret: RENDER_DEPLOY_HOOK_URL (dashboard → service → Settings →
# Deploy Hook). Without it the release job fails loudly rather than shipping
# nothing silently. Until a service exists at all, set the repo VARIABLE
# RENDER_DEPLOY=false so a tagged release skips the deploy step instead of
# failing on a hook that cannot exist yet (see references/tagged-deploy.md).
#
# NOTE — `autoDeploy: false` behaves differently depending on the service:
#   * EXISTING service: this line alone does NOTHING. It takes effect only once
#     the Blueprint is re-synced — flip auto-deploy off on the service in the
#     dashboard too, or every push to `main` still deploys regardless of the file.
#   * BRAND-NEW service created from this file: it is created with auto-deploy
#     already off. There is nothing to flip; just confirm it.
databases:
  - name: <project>-db
    plan: basic-256mb        # paid: smallest tier. Free tier = `free`, but it expires after 30 days.
    region: oregon
    postgresMajorVersion: "18"

services:
  - type: web
    name: <project>-web
    runtime: node
    plan: starter            # paid: smallest always-on tier. Free tier = `free` (spins down when idle).
    region: oregon
    branch: main             # deploy from main (release-please tags live here)
    autoDeploy: false        # OFF on purpose — see the header. The release-please workflow deploys the tagged commit.
    buildCommand: npm ci && npm run db:migrate && npm run build
    startCommand: npm start
    healthCheckPath: /        # point at an endpoint that returns 200 unauthenticated
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: <project>-db
          property: connectionString
      - key: NODE_ENV
        value: production
      # Secrets — Render prompts for these on apply (never commit values):
      - key: AUTH_SECRET
        sync: false
```

Conventions to bake in:
- **Service naming**: `<project>-db`, `<project>-web`, `<project>-worker`, etc. (the `<project>-` prefix is required.)
- **`autoDeploy: false`** so deploys are driven by the verified tag, not every push to `main`. This is the load-bearing line of the whole deploy model — with it on, the untagged promotion merge ships the feature code and the release commit ships again, two deploys per release with the wrong one going first (`references/tagged-deploy.md`). **On an existing service, flipping it in the file is only half the change** — auto-deploy must also be turned off on the service in the dashboard (or the Blueprint re-synced). **On a brand-new service created from this file**, it starts off; don't send the user chasing a toggle that's already correct. **This applies to every service in the file, staging included** — a repo with a `stage` branch gets a second service block, also `autoDeploy: false`, deployed from its pre-release tags and never from a push to `stage`.
- **`sync: false`** for every secret (auth secrets, API keys, credentials) — Render prompts for them on apply rather than reading from the repo.
- **Idempotent build steps** — anything in `buildCommand` (e.g. `db:migrate`, a seed) must be safe to re-run on every deploy.
- `region` is a placeholder — confirm with the user; don't assume Oregon.
- `plan` follows the free-vs-paid answer from the question above — never assume the tier; ask, then seed both the web and Postgres `plan:` lines to match.

With a Blueprint in place, CI still owns *when* to redeploy — the tag-gated step in `release-please.yml` (`references/tagged-deploy.md`) — while the Blueprint owns *what exists* in production.

For other known targets the equivalent IaC file is the natural analogue (Fly → `fly.toml`, Railway → `railway.toml`); generate it the same opt-in way. Vercel is mostly dashboard-driven, so `vercel.json` is optional — note that Vercel's own "disable automatic deployments for the production branch" setting is the `autoDeploy: false` equivalent and lives only in the dashboard.

## Per-component releases (standard for the fullstack monorepo)

The fullstack-monorepo release-please config produces per-component tags (`frontend-v1.2.0`, `backend-v1.2.0`), so a monorepo deploy uses this trigger:

```yaml
on:
  push:
    tags:
      - '*-v*.*.*'   # matches frontend-v1.2.0, backend-v1.2.0
      - 'v*.*.*'     # also matches single-package tags

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Determine which package
        id: which
        run: |
          tag="${GITHUB_REF#refs/tags/}"
          if [[ "$tag" =~ ^frontend-v ]]; then
            echo "package=frontend" >> $GITHUB_OUTPUT
          elif [[ "$tag" =~ ^backend-v ]]; then
            echo "package=backend" >> $GITHUB_OUTPUT
          else
            echo "package=all" >> $GITHUB_OUTPUT
          fi
      - run: echo "Deploying ${{ steps.which.outputs.package }}"
      # TODO: dispatch to per-package deploy steps
```

Use the single-tag `v*.*.*` flow only for single-package projects (or a fullstack app shipped as one unit via the single-package-at-root config). True frontend+backend monorepos use this per-component trigger.

## Notes for the report

- `environment: production` and `environment: staging` map to GitHub Environments. Set those up in **repo settings → Environments** to add per-env secrets and approval gates. Only create the `staging` environment if the repo actually has a `stage` branch.
- Deploy secrets use `${{ secrets.NAME }}` and live on the GitHub Environment, not in the repo.
- The TODO comments in the scaffolded file include the most common deploy patterns. The user picks one.

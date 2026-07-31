# Branch protection — `gh api` script + 403 fallback

Skip this step entirely if the visibility/plan check showed **free-tier + private repo** (GitHub returns 403 in that case — branch protection on private repos requires Pro). Otherwise, apply protection to `main`, `develop`, and (if staging enabled) `stage`.

The required status check `contexts` are derived from the actual CI job names in `.github/workflows/ci.yml` rather than hardcoded — different scaffold choices produce different jobs (e.g., `integration tests` is opt-in via `/testing-init`; a backend-only library has no `e2e tests` or `production build`), and hardcoding a list silently blocks every PR when a required context is one no job actually produces.

## Bash

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Derive required-context names from ci.yml's job-level `name:` fields.
#
# Our CI templates use 2-space indent, so job names sit at exactly 4 leading
# spaces. The workflow's own top-level `name:` is at 0 spaces (excluded), and
# step names (`- name: ...`) are at 6+ with a leading dash (excluded).
#
# Reads one name per line from stdin/the file.
derive_contexts() {
  if [[ ! -f .github/workflows/ci.yml ]]; then
    return
  fi
  grep -E '^    name:' .github/workflows/ci.yml \
    | sed -E 's/^    name:[[:space:]]*//'
}

CONTEXTS_JSON=$(derive_contexts | jq -R . | jq -s .)

if [[ "$CONTEXTS_JSON" == "[]" || "$CONTEXTS_JSON" == "null" ]]; then
  echo "Couldn't derive required status-check contexts from .github/workflows/ci.yml — skipping branch protection. Apply it manually in repo settings, or re-run this step after ci.yml is wired up." >&2
  exit 1
fi

protect_branch() {
  local branch=$1
  jq -n --argjson contexts "$CONTEXTS_JSON" '{
    required_status_checks: { strict: true, contexts: $contexts },
    enforce_admins: false,
    required_pull_request_reviews: {
      required_approving_review_count: 0,
      dismiss_stale_reviews: false,
      require_code_owner_reviews: false
    },
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false
  }' | gh api -X PUT "repos/$REPO/branches/$branch/protection" --input -
}

protect_branch main
protect_branch develop
# protect_branch stage   # only if staging was opted in
```

## Why dynamic, not hardcoded

An earlier version hardcoded the list — `["lint + typecheck", "unit tests", "integration tests", "e2e tests", "production build"]` — assuming every scaffold produces the same fixed set. It never did, and the job consolidation (5→3) makes the point sharper: the current default emits `["checks", "e2e tests", "production build"]`, and even that varies:

- `checks` bundles lint + format:check + typecheck + the unit-test step into one job (the old `lint + typecheck` and `unit tests` contexts no longer exist) — so a list written against the old names would hang forever.
- `integration tests` is opt-in during `/testing-init` (the default Next.js scaffold produces 3 jobs — `checks`, `e2e tests`, `production build` — not 4).
- A Python-only library has no `e2e tests` job.
- Backend-only scaffolds may have no `production build` job.

When a required context is in the protection rules but no CI job emits it, GitHub keeps the PR's "Required" check in a perpetual pending state — the PR cannot merge, even after CI is fully green. The dynamic derivation reads the actual job names from `ci.yml` after `/gh-actions-init` and `/testing-init` have finished writing it, so the contexts always match the real jobs.

## Conventions this depends on

- **`ci.yml` uses 2-space indent.** Our templates write it this way and prettier formats it that way on commit; user-edited `ci.yml` with 4-space indent would silently produce zero contexts. The empty-contexts guard catches this case and bails with a clear message.
- **Every CI job has an explicit `name:` field.** Without it, GitHub falls back to the YAML key as the context, but our grep wouldn't pick it up. The CI templates in `gh-actions-init` and `testing-init` always set `name:`.

## If protection fails with 403

Surface this exact message:

> Branch protection couldn't be applied — GitHub returned a **403 (forbidden — your account/plan isn't allowed to do this)**. Branch protection requires GitHub Pro for private repos. You have three options:
>
> 1. Make the repo public (everything works, free): `gh repo edit --visibility public`
> 2. Upgrade to GitHub Pro (~$4/mo) — branch protection works on private repos
> 3. Skip it for now (your local pre-commit hooks + global git rules still protect you, and CI still runs on PRs — you just *can* merge a failing PR if you ignore the red X)

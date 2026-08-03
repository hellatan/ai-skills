# release-please

Automates versioning, changelogs, tags, and GitHub releases via PRs driven by conventional commits. Three files:

1. `.github/workflows/release-please.yml` — the workflow
2. `.github/release-please-config.json` — release type + package config
3. `.github/.release-please-manifest.json` — current versions per package

## How it works

1. Push to `main` — the `develop → main` **promotion merge**. This is the only human gate in the chain.
2. release-please scans new conventional commits since the last release.
3. It opens (or updates) a "release PR" with a generated `CHANGELOG.md` and a version bump — and the same run **auto-merges** that PR (squash, with the PAT).
4. The release-PR merge fires a **second** run of the same workflow, which tags the commit (e.g. `v1.2.0`) and creates a GitHub Release.
5. That second run **verifies the tag exists on the remote and then deploys that exact commit** — the deploy lives in this workflow, not a separate `deploy.yml` on a tag trigger.

Steps 3–5 are the "tagged-only deploy" model: platform auto-deploy is off, so a push to `main` never ships by itself and production always runs the exact tagged commit, exactly once. The design, the deploy step, the auto-merge step, and the non-Render caveats are in **`references/tagged-deploy.md`** — read it before changing anything in this chain. Two of its five parts are release-please *config* and live in this file: root-scoping the package, and `changelog-sections` un-hiding every commit type.

## Workflow

`.github/workflows/release-please.yml` (with the `verify-tag` steps folded in — see `references/release-verification.md` for what they do):

```yaml
name: release-please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: release-please
  cancel-in-progress: false

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4 # required for the local ./.github/actions/discord-alert composite

      - id: release
        uses: googleapis/release-please-action@v5
        with:
          # Author the release PR as a non-bot identity (a PAT in repo secrets,
          # not the built-in GITHUB_TOKEN). PRs opened by github-actions[bot]
          # leave their CI run stuck in "action_required" (manual approval), so
          # the release PR never goes green on its own. A real-identity token
          # also restores CI triggering on the PR (the GITHUB_TOKEN anti-recursion
          # rule suppresses it). Secret needs contents:write + pull-requests:write.
          token: ${{ secrets.RELEASE_PLEASE_TOKEN }}
          # Pin the release branch. release-please defaults target-branch to the
          # repo's DEFAULT branch — which gitflow-init sets to `develop` — so
          # without this it manages develop and opens release PRs against
          # develop instead of main, even though it's triggered by main pushes.
          target-branch: main
          config-file: .github/release-please-config.json
          manifest-file: .github/.release-please-manifest.json

      # verify-tag: a merged release PR MUST produce a tag. These steps (Evaluate
      # release outcome / Alert on failure / Fail the run) catch a release-please
      # step failure AND the silent case where a release PR merges, the step
      # reports success, but no tag is created. They also emit the `released`
      # output the deploy step below gates on. Full step bodies + the companion
      # release-health.yml + discord-alert composite are in
      # references/release-verification.md — scaffold them together.

      # Deploy tagged release — runs only when `released == 'true'`, and deploys
      # github.sha (the commit just tagged). Platform auto-deploy is OFF, so this
      # is the only thing that ships production.
      #
      # Auto-merge the release PR — squash-merges the pending release PR with the
      # PAT so the merge re-triggers this workflow and cuts the tag.
      #
      # Both step bodies, the RELEASE_AUTOMERGE pause switch, and the non-Render
      # platform variants are in references/tagged-deploy.md.
```

The `verify-tag` steps that complete this job, plus the companion `release-health.yml` and `discord-alert` composite, live in `references/release-verification.md`; the **deploy** and **auto-merge** steps live in `references/tagged-deploy.md`. Copy them from there rather than hand-rolling — and note in particular that a tag check must **not** read `steps.release.outputs.release_created` / `.tag_name`: those are empty for every non-root package path, including the monorepo config below. Scaffold all of it **alongside** release-please (same skip condition). The alerting no-ops safely if the webhook secret is unset.

⚠️ **Never scaffold auto-merge without `verify-tag`.** Auto-merge removes the human who would have noticed a release that didn't tag; the verification steps are the replacement. And never gate the deploy on anything looser than `released == 'true'` — that output is `true` only after the tag ref is confirmed on the remote.

Both `branches:` (the trigger) and `target-branch:` (the branch release-please
manages) must point at the release branch — `main` here. **Setting
`target-branch` is not optional in a gitflow repo:** `gitflow-init` makes
`develop` the default branch, and an unset `target-branch` silently defaults to
that default branch, so release-please opens its release PRs against `develop`
(head `release-please--branches--develop`) and never tags `main`. Adjust both
lines together if the release branch isn't `main` (rare).

## Why a PAT (`RELEASE_PLEASE_TOKEN` — required, not optional)

With the default `GITHUB_TOKEN`, release-please opens its PR as `github-actions[bot]`, which breaks the release flow two ways (both confirmed live):

1. **No CI trigger.** GitHub deliberately does **not** fire workflows for `GITHUB_TOKEN`-created events (recursion guard), so the `pull_request` CI never runs on the release PR — and with strict branch protection it can't satisfy a required check.
2. **Manual approval gate.** Workflow runs on bot-authored PRs sit in **`action_required`** — they need a manual "Approve and run" click before CI executes. Even when CI is otherwise wired to run, the release PR never goes green on its own.

Authoring the PR with a real-identity token fixes both, so the workflow above passes `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}` unconditionally. **Every new repo needs this secret set up — surface it in the report as a blocking step:**

1. Use a fine-grained PAT with **Contents: read/write** + **Pull requests: read/write**.
2. **Add the repo to the PAT's repository access.** A fine-grained PAT grants either "All repositories" or "Only select repositories" — and if it's the select list, **the repo must be in it**. This is the most-missed step. The repo is *not* added automatically, and a select-list PAT doesn't cover repos created after it.
3. Have the user add it as the repo secret (it prompts for the value — don't paste the PAT into chat):

```bash
gh secret set RELEASE_PLEASE_TOKEN --repo <owner>/<repo>
```

Caveats:

- **Public-repo trap (silent until PR creation).** A PAT can *read* any public repo even when it's **not** in the PAT's access list, so `gh pr list` succeeds and everything looks wired — but **write** operations need the repo explicitly selected. The symptom is a workflow that fails *only* at the create step with `pull request create failed: GraphQL: Resource not accessible by personal access token (createPullRequest)` while earlier read steps passed. The fix is step 2 (add the repo to the access list), **not** a scope change — `Pull requests: write` is already on; it just doesn't apply to an unselected repo. (Confirmed live on the public `hellatan/claude-skills` while the same PAT created PRs fine on selected private repos.)
- A fine-grained PAT belongs to a person and **expires** (≤1 yr) — renew on the schedule you pick. A **GitHub App token** avoids expiry and scales across repos (more setup; better for shared/long-lived repos). Either works.
- If the secret is missing, the `token:` input renders empty and the workflow fails with an auth error on its first `main` push — the fix is to add the secret, not to fall back to `GITHUB_TOKEN`.

The `/rebuild` comment workflow (`rebuild.md`) remains the manual fallback for re-running flaky or stuck CI, but it is no longer the primary way to get checks on release PRs.

## Config — single package (most common)

`.github/release-please-config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "node",
      "include-component-in-tag": false,
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": false,
      "changelog-sections": [
        { "type": "feat", "section": "Features" },
        { "type": "fix", "section": "Bug Fixes" },
        { "type": "perf", "section": "Performance Improvements" },
        { "type": "revert", "section": "Reverts" },
        { "type": "refactor", "section": "Code Refactoring" },
        { "type": "docs", "section": "Documentation" },
        { "type": "chore", "section": "Chores" },
        { "type": "style", "section": "Styles" },
        { "type": "test", "section": "Tests" },
        { "type": "build", "section": "Build System" },
        { "type": "ci", "section": "Continuous Integration" }
      ]
    }
  },
  "include-v-in-tag": true,
  "pull-request-title-pattern": "chore: release${component} ${version}",
  "group-pull-request-title-pattern": "chore: release${component} ${version}"
}
```

For a monorepo whose **one deployable app** lives in a subdirectory, keep the package at `"."` and add `extra-files` to mirror the root version into the app — see "Scope the package to the repo root" below. That is not a stylistic preference; scoping to the app directory silently drops whole classes of change out of the release stream.

This shape (minus `changelog-sections`) was verified end-to-end on a throwaway repo: a real `feat` commit produced a `chore: release X.Y.Z` PR that, on merge, automatically created a clean `vX.Y.Z` tag + GitHub release with zero manual steps. `changelog-sections` and root-scoping are the two additions verified separately on a production app (see the two sections below). Two non-obvious requirements make the base shape work:

- **No `package-name`.** With an explicit `package-name` *and* `include-component-in-tag: false`, release-please expects the package's component in the merged release-PR title to associate the release — but `include-component-in-tag: false` strips the component from the title. They never match, so release-please logs `PR component: undefined does not match configured component: <name>` and **silently skips creating the tag/release** ([googleapis/release-please#2214](https://github.com/googleapis/release-please/issues/2214)). Omitting `package-name` makes release-please match by path (`.`) instead, which round-trips correctly and still yields clean `vX.Y.Z` tags. (`changelog-path` is also omitted — `CHANGELOG.md` is the default.)
- **`group-pull-request-title-pattern` is required, not just `pull-request-title-pattern`.** In grouped mode (`separate-pull-requests: false`, the default) release-please titles the release PR from the **group** pattern, not the per-package one. If only `pull-request-title-pattern` is set, the group pattern defaults to a version-less `chore: release main`; a release PR whose title lacks `${version}` can't be parsed on merge, so the release strands ([googleapis/release-please#2712](https://github.com/googleapis/release-please/issues/2712)). Set both to the same value. `${component}` renders empty for a single root package, so titles read `chore: release 0.1.2` and tags read `v0.1.2`.

`release-type` options (the per-package `release-type` above):
- `node` — for Node/TS projects, bumps `package.json`
- `python` — for Python projects, bumps `pyproject.toml`
- `simple` — manifest-only, no language-specific version file

## ⚠️ Scope the package to the repo root (`"."`), not the app directory

**release-please only counts commits that touch files under a package's path.** Point the package at `apps/web` and every change *outside* that directory is invisible to it: a fix confined to an internal workspace package that gets bundled into the app at build time, a dependency bump in the root lockfile, a CI or tooling change. Those produce **no release**, therefore no tag — and with tagged-only deploys (`references/tagged-deploy.md`), **no deploy**. The code is merged, present on `main`, and dead in production. Nothing fails; nothing alerts. This was a real production incident, not a hypothetical.

Root-scoping means any file anywhere counts. For a monorepo with one deployable app, the **root** `package.json` holds the version and `extra-files` mirrors it into the app's:

```json
{
  "packages": {
    ".": {
      "release-type": "node",
      "include-component-in-tag": false,
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": false,
      "extra-files": [{ "type": "json", "path": "apps/web/package.json", "jsonpath": "$.version" }],
      "changelog-sections": [ /* …as above… */ ]
    }
  }
}
```

Internal workspace packages stay `"private": true` and unversioned — nothing tracks them, nothing tags them.

Chosen over release-please's **`node-workspace` plugin**, which versions private packages too and can produce a second stream of tags that the deploy gate then has to disambiguate. For a single deployable, root-scoping is strictly simpler and has no failure mode of its own.

The manifest keys must match: `{ ".": "1.4.2" }`. Retrofitting a repo that was scoped to a subdirectory means moving the manifest key *and* the version into the root `package.json`; the existing tags are unaffected because `include-component-in-tag: false` already made them plain `vX.Y.Z`.

**When root-scoping is the wrong answer:** a repo with several *independently deployed* services. See the multi-deploy-monorepo section of `references/tagged-deploy.md` and the per-component config further down this file.

## ⚠️ `changelog-sections` — un-hide every commit type, or docs-only releases silently vanish

**release-please skips the release entirely when the changelog would be empty.** By default only `feat`, `fix`, and `perf` are visible; `chore` / `docs` / `ci` / `style` / `test` / `build` / `refactor` are hidden. So a promotion carrying only docs or CI commits generates an empty changelog, cuts **no release**, and — with tagged-only deploys — never ships. `main` drifts ahead of production again.

Listing every type (as in the config above) makes every promotion produce a release, so `main == production` holds with no exceptions to remember.

**Do not use `always-bump-patch` for this.** It looks like the same fix and isn't: it flattens `feat` → patch, so the version stops carrying meaning. The **default** versioning strategy already floors every release at a patch while keeping `feat` → minor and breaking → major — exactly what's wanted. `changelog-sections` changes *visibility*, not the bump computation.

Tradeoff worth stating to the user: a docs-only promotion now triggers a build + deploy — a near-no-op rebuild. That is the price of a strict `main == production` invariant, and it is the right trade for anything with a real deploy.

## Config — single package, no language version file (`release-type: simple`)

For a repo with **no `package.json` / `pyproject.toml`** to bump — a chezmoi/shell dotfiles repo, a config-only repo, a pile of scripts — use `release-type: "simple"`. It's the right pick whenever there's no language version file: release-please tracks the version in the manifest alone (manifest-only) and still cuts clean `vX.Y.Z` tags + GitHub releases from conventional commits.

The config mirrors the verified node single-package shape above — omit `package-name`, set **both** title patterns, `include-component-in-tag: false` — only `release-type` changes:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "include-component-in-tag": false,
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": false
    }
  },
  "include-v-in-tag": true,
  "pull-request-title-pattern": "chore: release${component} ${version}",
  "group-pull-request-title-pattern": "chore: release${component} ${version}"
}
```

The same two non-obvious requirements from the node block apply unchanged: **omit `package-name`** (release-please matches by path `.` instead of an unmatchable component, which would otherwise silently strand the tag) and set **both** `pull-request-title-pattern` and `group-pull-request-title-pattern` (grouped mode titles from the group pattern; a version-less title can't be parsed on merge). `${component}` renders empty for the single root package, so titles read `chore: release 0.1.2` and tags read `v0.1.2`.

Add the same `changelog-sections` block as the node config above if the repo deploys anything — the empty-changelog skip is release-type-agnostic, and a config-only repo is *especially* prone to promotions made entirely of `chore:` / `docs:` commits.

Seed the manifest at `0.1.0` — with no language version file to mirror, the manifest is the sole source of truth, and a `0.0.0` seed still trips the `1.0.0` first-release bootstrap (see "Manifest" below).

This exact config is verified live on a chezmoi-managed shell/dotfiles repo with no version file.

## Config — fullstack monorepo (frontend + backend)

A monorepo tracks each package's version independently, so its tags must be **per-component** (`backend-v1.2.0`, `frontend-v1.2.0`) and each package needs its **own** release PR. This exact shape was verified end-to-end (see the note at the end of this section):

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "separate-pull-requests": true,
  "packages": {
    "backend": {
      "release-type": "python",
      "package-name": "<project>-backend",
      "component": "backend"
    },
    "frontend": {
      "release-type": "node",
      "component": "frontend"
    }
  },
  "include-v-in-tag": true,
  "pull-request-title-pattern": "chore: release ${component} ${version}"
}
```

The single-package fixes above do **not** transfer verbatim — the per-component-tag case behaves differently in three ways, each confirmed live:

- **Per-component tags are mandatory; you cannot collapse the monorepo into one `v1.2.0` tag.** `include-component-in-tag` is left at its default (`true`), so each package tags as `backend-v…` / `frontend-v…`. The tempting "release everything under one `v1.2.0` tag" via `include-component-in-tag: false` only survives while *every* release bumps *all* packages in lockstep. The first commit that touches a single package diverges their versions, and release-please then can't map the component-less tag back to the one package that bumped — it logs `There are untagged, merged release PRs outstanding - aborting` and **silently creates no tag or release**. (Verified: a symmetric first release tagged a single `v0.2.0` cleanly, but a later backend-only `fix:` merged with **no** `v0.2.1` produced — the release stranded.)
- **Keep `package-name` on the Python package.** Unlike the node single-package block (which *removes* it), `package-name` is **required** for non-node release types, so `backend` keeps it; `frontend` (node) doesn't need it. `component` is set on both so the tags read `backend-v…` / `frontend-v…` rather than the full package name.
- **`separate-pull-requests: true`, not grouped.** Grouped mode (the default) puts both packages in one release PR, but a single title can't carry two different per-component versions, so it renders version-less (`chore: release`) and can't be associated on merge — the release strands with the same `untagged … aborting` error (verified). Separate PRs each carry their own `${component} ${version}`, parse on merge, and tag independently. No `group-pull-request-title-pattern` is needed because there is no grouped PR.

**Tags are `backend-v1.2.0` / `frontend-v1.2.0`, so `deploy.yml` must trigger on the per-component pattern (`*-v*.*.*`), not `v*.*.*`** — see `references/deploy-stub.md`.

**Caveat — merge sibling release PRs one at a time.** When more than one package has a pending release (notably the very first release, where everything bumps at once), each is its own PR editing the shared `.release-please-manifest.json`. Merging one makes the others conflict, and release-please leaves an already-open PR's branch as-is (`PR … remained the same`) rather than rebasing it onto the moved `main`. Recovery is clean and confirmed: **close** the conflicted sibling PR and let release-please **recreate** it against the new `main` on its next run — the recreated PR merges without conflict and tags correctly.

> **Want one `v1.2.0` tag instead (app shipped as a single unit)?** If frontend and backend always deploy together, skip the per-component setup entirely and use the **single-package config above** with the repo root as the one package (`"."`). release-please then bumps the root version file and cuts a single `v1.2.0` tag for the whole repo, keeping the default `v*.*.*` deploy trigger; the per-package version files just aren't tracked individually, which is fine when you never ship them apart. This sidesteps every per-component footgun listed above.

**Verified end-to-end.** On a throwaway frontend(node)+backend(python) repo seeded at `0.1.0`/`0.1.0`, a `feat` touching both packages opened two release PRs (`chore: release backend 0.2.0`, `chore: release frontend 0.2.0`); merging them — closing and letting release-please recreate the second to clear the manifest conflict — produced clean `backend-v0.2.0` and `frontend-v0.2.0` tags + GitHub releases with no manual version edits. The two strand modes called out above (`include-component-in-tag: false` divergence; grouped version-less title) were each reproduced live on parallel throwaway repos to confirm they are real, not theoretical.

## Manifest — match current version

`.github/.release-please-manifest.json`:

```json
{
  ".": "0.1.0"
}
```

The version here **must match** the project's current version in `package.json` / `pyproject.toml`. If they diverge, release-please's first PR generates a confusing changelog.

For brand-new projects (`project-scaffold` flow): start at `0.1.0` — **not `0.0.0`**. When the manifest reads exactly `0.0.0` and no git tag exists yet, release-please hardcodes the first release to `1.0.0` regardless of commit type, ignoring the `bump-minor-pre-major` / `bump-patch-for-minor-pre-major` options ([googleapis/release-please#2087](https://github.com/googleapis/release-please/issues/2087); hit live — one `fix:` commit produced a release PR proposing `1.0.0`). Seeding the manifest + `package.json` / `pyproject.toml` at a normal pre-1.0 version like `0.1.0` sidesteps the bootstrap entirely; release-please then computes the first release as a normal bump from that baseline — a `feat:` → `0.2.0`, a `fix:` → `0.1.1`. The `0.1.0` seed paired with the corrected single-package config above is the exact combination verified end-to-end on a throwaway repo.

For retrofitting an existing project: read the current version from the project file and use it. Don't reset it — that would lie about the project's history.

Monorepo manifest — one entry per package, keyed by the package's path (matching the `packages` keys in the config):

```json
{
  "backend": "0.3.1",
  "frontend": "0.3.1"
}
```

The same `0.0.0` → `1.0.0` bootstrap trap applies per package, so brand-new monorepos seed each entry at `0.1.0` (not `0.0.0`), matching each package's `pyproject.toml` / `package.json`. Retrofits use each package's current version.

## Conventional commits cheat sheet

release-please decides version bumps from commit messages:

| Prefix | Bump | Example |
|---|---|---|
| `feat:` | minor (0.X.0) | `feat: add dark mode` |
| `fix:` | patch (0.0.X) | `fix: handle null user` |
| `feat!:` / `BREAKING CHANGE:` | major (X.0.0) | `feat!: drop legacy API` |
| `chore:` / `docs:` / `refactor:` / `test:` / `ci:` | none (shows in changelog) | `chore: bump deps` |

If the project doesn't already enforce conventional commits, surface this in the report — release-please depends on the convention to do its job. Optional follow-up: `precommit-init` could add a commit-message hook (`commitlint`) but that's a separate concern.

## Why we skip release-please if any of the three files exist

release-please's state is a delicate combo of these three files plus the project's actual git history. If a previous release-please setup has been running, its manifest version is the only correct starting point — we shouldn't overwrite it. If a config exists but the workflow doesn't (or vice versa), there's likely an in-progress migration we shouldn't disturb.

When skipping, surface this in the report:
> Skipped release-please scaffolding — `.github/release-please-config.json` already exists. If the existing setup is broken, edit it manually rather than asking me to regenerate it.

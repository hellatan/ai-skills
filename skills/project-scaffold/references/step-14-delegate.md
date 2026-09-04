# Step 14 — Delegate to sister skills

`project-scaffold` doesn't own test-runner or workflow templates. Step 14 delegates to two specialized skills, in order. Both detect each other's outputs and only add what's missing, so run order is unambiguous.

## Order

1. **Run `/testing-init`'s execution phase first.** It owns:
   - Test runner installs (Vitest + Playwright for Node, pytest for Python; React projects also get `@testing-library/react` + `jsdom`).
   - Runner configs (`vitest.config.ts`, `playwright.config.ts`, `[tool.pytest.ini_options]` block in `pyproject.toml`).
   - Passing smoke-test stubs.
   - `test` / `test:unit` / `test:integration` / `test:e2e` scripts.
   - Test steps/jobs in `.github/workflows/ci.yml` (creates the file if it doesn't exist): the unit-test step lives in a `checks` job (created here, with `gh-actions-init`'s lint/typecheck steps to be prepended later — unit stays last), plus `integration`/`e2e` as their own jobs.

2. **Run `/gh-actions-init`'s execution phase second.** It owns:
   - The `checks` job's lint + format:check + typecheck steps — merged into the `checks` job `testing-init` just seeded (unit stays last) — plus the `build` job.
   - `release-please.yml` + `release-please-config.json` + `.release-please-manifest.json`.
   - The tagged-only deploy: the deploy + release-PR auto-merge steps folded into `release-please.yml`, and `autoDeploy: false` (or the platform equivalent) in the deploy config. A standalone `deploy.yml` with the deploy-target picker only when one is actually needed — see `gh-actions-init/references/tagged-deploy.md`.
   - `claude-code-review.yml` — automated PR review, gated on `draft == false` so a draft isn't reviewed on open and then again on `ready_for_review`. Needs the `CLAUDE_CODE_OAUTH_TOKEN` repo secret (Step 17).
   - **The staging environment, but only if Step 6 asked for one — and you must tell it so** (next section).

## ⚠️ Staging: pass the Step 6 answer in, don't let it probe

`gh-actions-init` decides whether to scaffold a staging environment by running `git ls-remote --heads origin stage`. That is correct for its own retrofit path and **wrong here**, because of ordering: this step runs at Step 14, the GitHub repo isn't created until **Step 17**, and `stage` isn't created even locally until **Step 15**. The probe therefore returns empty on every new scaffold, `gh-actions-init` correctly concludes "no `stage` branch → no staging environment", and a user who answered `yes` gets a `stage` branch that deploys nothing — with nothing in the run flagging the omission.

Same rule as the stack: **pass the decision forward instead of letting the sub-skill re-detect it.** State it explicitly when invoking `gh-actions-init` — *"Step 6 answered yes to staging; the `stage` branch will exist after Step 15. Scaffold the staging environment as if the probe had found it."*

When staging **is** on, `gh-actions-init` additionally owns:

- `.github/workflows/release-please-stage.yml` (`target-branch: stage`, plus `config-file` / `manifest-file` naming the stage-specific paths).
- `.github/release-please-config.stage.json` + `.github/.release-please-manifest.stage.json` — the stage config carries `"versioning": "prerelease"`, `"prerelease": true`, `"prerelease-type": "rc"`, and a distinct `"changelog-path"`. Do not drop any of the four; `gh-actions-init/references/tagged-deploy.md` explains what each one silently breaks.
- A second service block in the deploy config, also `autoDeploy: false`.
- **Skipping** `develop-to-main-pr.yml` + `main-to-develop-backmerge.yml` (single-hop promotion workflows; the chain is now two hops).

Step 17 then sets `RENDER_STAGE_DEPLOY=false` alongside `RENDER_DEPLOY=false`. When staging is **off** — the default — none of the above is written, and that is a complete outcome, not a deferred one.

## Manifest-version invariant (new projects)

For brand-new projects (this skill's path), the release-please manifest must start at `0.1.0` — **not `0.0.0`** (an exact-`0.0.0` manifest bootstraps the first release straight to `1.0.0`; canonical explanation + issue link: `gh-actions-init/references/release-please.md`, "Manifest — match current version"). `package.json` / `pyproject.toml` `version` must match the manifest. Step 11 already sets both to `0.1.0`; just confirm `gh-actions-init` reads that current value rather than starting from a different default.

## Sub-skill protocol when invoked from project-scaffold

The sister skills have their own detection and summary-halt steps designed for retrofitting existing projects. When invoked from `project-scaffold`, those steps are redundant:

- **Skip their detection step** — the stack is already known from project-scaffold's Step 2 (project name) and Step 4 (framework selection). Pass it forward instead of re-detecting.
- **Skip their summary-halt step** — project-scaffold's Step 9 confirmation already gathered the user's "go" for the entire scaffold. Re-prompting would be friction.
- **Run their execution + smoke-test + report steps as documented.**
- **Surface their reports inline** — fold them into project-scaffold's Step 21 final report rather than printing two separate reports back-to-back.

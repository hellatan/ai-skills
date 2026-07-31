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
   - `deploy.yml` with the deploy-target picker.

## Manifest-version invariant (new projects)

For brand-new projects (this skill's path), the release-please manifest must start at `0.1.0` — **not `0.0.0`** (an exact-`0.0.0` manifest bootstraps the first release straight to `1.0.0`; canonical explanation + issue link: `gh-actions-init/references/release-please.md`, "Manifest — match current version"). `package.json` / `pyproject.toml` `version` must match the manifest. Step 11 already sets both to `0.1.0`; just confirm `gh-actions-init` reads that current value rather than starting from a different default.

## Sub-skill protocol when invoked from project-scaffold

The sister skills have their own detection and summary-halt steps designed for retrofitting existing projects. When invoked from `project-scaffold`, those steps are redundant:

- **Skip their detection step** — the stack is already known from project-scaffold's Step 2 (project name) and Step 4 (framework selection). Pass it forward instead of re-detecting.
- **Skip their summary-halt step** — project-scaffold's Step 9 confirmation already gathered the user's "go" for the entire scaffold. Re-prompting would be friction.
- **Run their execution + smoke-test + report steps as documented.**
- **Surface their reports inline** — fold them into project-scaffold's Step 21 final report rather than printing two separate reports back-to-back.

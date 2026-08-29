# Sister-skill dependency

`project-scaffold` delegates several steps to specialized skills. **All sister skills below must be installed** before this skill can complete a scaffold.

## The required sister skills

- **`/testing-init`** (Step 14) — owns test runner setup (Vitest / Playwright / pytest), test stubs, test scripts, and the test steps/jobs in `ci.yml` (the unit-test step folds into the `checks` job; `integration`/`e2e` are their own jobs).
- **`/gh-actions-init`** (Step 14) — owns the `checks` job structure (lint + format:check + typecheck) + the `build` job, release-please config + workflow, and the deploy stub.
- **`/gitflow-init`** (Steps 18 + 19) — owns branch-protection setup and default-branch configuration.
- **`/precommit-init`** (Step 13) — owns pre-commit installation, polyglot config generation, and hook activation.
- **`/claude-md-init`** (Step 10) — owns per-stack CLAUDE.md template selection and writing.

All ship as part of the same `ai-skills` repo. Running `scripts/install.sh` installs every skill together, so the dependency is already satisfied for anyone installing from the repo. The check below mainly guards against:

- Users who installed `/project-scaffold` standalone (e.g., copied the folder without the sisters)
- Users who symlinked or curated a subset of skills
- A skill being deleted or renamed mid-session

## Upfront availability check (Flow Step 1)

Before asking the user any project-shape questions in Step 1, verify all sister skills appear in the list of available skills (visible to Claude in system reminders / the available-skills section).

If any is missing, abort immediately — don't proceed to Step 1 — with this message:

> `/project-scaffold` delegates several steps to sister skills (`/testing-init`, `/gh-actions-init`, `/gitflow-init`, `/precommit-init`, `/claude-md-init`). One or more isn't installed in this Claude Code instance. Install the full skill family — they ship together in the `ai-skills` repo — then retry. (For the typical setup: `~/projects/ai-skills/scripts/install.sh`.)

Reasoning: a partial scaffold that gets several steps in and dead-ends at a delegation point is much worse than a fast upfront refusal. Failing before user time is invested keeps the failure cheap.

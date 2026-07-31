# claude-skills

Personal monorepo of Claude skills. Each skill lives under `skills/<skill-name>/` and follows the Anthropic skills convention (SKILL.md + optional `references/`, `scripts/`, `assets/`).

> **Living doc:** when you learn a durable, non-obvious fact about this repo (a gotcha, convention, or footgun), add it to the matching section of this file in the same PR — don't leave it in chat.

## Lifecycle

- Feature branches off `develop`, never `main`.
- PRs target `develop`. CI must pass before merge.
- Release: PR `develop` → `main`. release-please opens a release PR with version bump + changelog. Merging it tags the commit.
- Skills are installed locally via `scripts/install.sh` (see README).

## Project map

- `skills/<skill-name>/` — one folder per skill
- `scripts/install.sh` — symlinks each skill into `~/.claude/skills/`
- `scripts/validate.sh` — sanity-checks every SKILL.md (frontmatter present, name matches folder, etc.)
- `.github/workflows/` — CI for validation + release-please
- `docs/architecture.html` — living system map (open in a browser). Update it when components, flows, or failure modes change.

## Conventions

- Skill folder names are lowercase, hyphenated. `name` in frontmatter must match folder name.
- Skills compose; each domain has exactly one owning skill (test *commands/steps* → `testing-init`, CI *job structure* incl. the shared `checks` job + workflows/release-please → `gh-actions-init`, branches/protection → `gitflow-init`, hooks → `precommit-init`, CLAUDE.md → `claude-md-init`; `project-scaffold` and `release-workflow-init` orchestrate). The one seam where two skills co-write a single job: `gh-actions-init` owns the `checks` **job** (lint + format:check + typecheck), and `testing-init` folds its unit-test **step** into it — job vs. steps (`gh-actions-init/references/ci-structure.md` ↔ `testing-init/references/ci-test-job.md`). Don't restate another skill's owned content — cross-reference it by path (`<skill>/references/<file>.md`). A one-line summary at the point of use is fine; a second copy of the full explanation is not.
- `description` field in frontmatter must be "pushy" (explicit trigger contexts) so Claude invokes correctly.
- Conventional commits required (release-please drives off them).
- See `skills/<skill>/SKILL.md` for individual skill details.

## Install (development)

```bash
./scripts/install.sh
```

This symlinks each `skills/<skill-name>/` into `~/.claude/skills/<skill-name>`. Edits in the repo are immediately live.

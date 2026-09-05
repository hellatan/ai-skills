# ai-skills

Personal monorepo of Claude skills. Each skill lives under `skills/<skill-name>/` and follows the Anthropic skills convention (SKILL.md + optional `references/`, `scripts/`, `assets/`).

> **Living doc:** when you learn a durable, non-obvious fact about this repo (a gotcha, convention, or footgun), add it to the matching section of this file in the same PR — don't leave it in chat.

## Lifecycle

- Feature branches off `develop`, never `main`.
- PRs target `develop`. CI must pass before merge.
- Release: PR `develop` → `main`. release-please opens a release PR with version bump + changelog. Merging it tags the commit.
- Skills are installed locally via `scripts/install.sh` (see README).

## Project map

- `skills/<skill-name>/` — one folder per skill
- `scripts/install.sh` — symlinks each skill into `~/.claude/skills/`, prunes links to skills this repo no longer has, and installs the git hooks below
- `.githooks/` — `post-merge` / `post-checkout` / `post-rewrite`, each re-running `install.sh --quiet` so a pulled-in skill is usable without a manual install step
- `scripts/validate.sh` — sanity-checks every SKILL.md (frontmatter present, name matches folder, etc.)
- `.github/workflows/` — CI for validation + release-please
- `docs/architecture.html` — living system map (open in a browser). Update it when components, flows, or failure modes change.

## Conventions

- Skill folder names are lowercase, hyphenated. `name` in frontmatter must match folder name.
- Skills compose; each domain has exactly one owning skill (test *commands/steps* → `testing-init`, CI *job structure* incl. the shared `checks` job + workflows/release-please → `gh-actions-init`, branches/protection → `gitflow-init`, hooks → `precommit-init`, CLAUDE.md → `claude-md-init`; `project-scaffold` and `release-workflow-init` orchestrate). The one seam where two skills co-write a single job: `gh-actions-init` owns the `checks` **job** (lint + format:check + typecheck), and `testing-init` folds its unit-test **step** into it — job vs. steps (`gh-actions-init/references/ci-structure.md` ↔ `testing-init/references/ci-test-job.md`). Don't restate another skill's owned content — cross-reference it by path (`<skill>/references/<file>.md`). A one-line summary at the point of use is fine; a second copy of the full explanation is not.
- `description` field in frontmatter must be "pushy" (explicit trigger contexts) so Claude invokes correctly.
- Conventional commits required (release-please drives off them).
- **A runnable `bash` block in a reference file is code — execute it before committing.** Extract it *verbatim* from the `.md` (never retype it; retyping tests a different program than the one that ships) and run it against fixtures covering each verdict it can produce. Doc-only changes feel exempt from "run it"; they aren't. Three defects in one commit came from proofreading a snippet instead of running it — a loop variable used outside its loop, a hardcoded key the prose three lines below said not to use, and a missing `shopt -s nullglob`. The first would have made an audit check false-flag every *correctly* configured repo. See `skills/ci-baseline-audit/references/checks.md` check 13 for the shape a tested snippet ends up in.
- **If a note under a code block says "but actually X", fix the block to do X and delete the note.** A caveat beneath runnable code is an admission the code is wrong, and readers copy the code, not the caveat. A caveat that genuinely can't be coded goes *above* the block.
- See `skills/<skill>/SKILL.md` for individual skill details.

## Install (development)

```bash
./scripts/install.sh
```

This symlinks each `skills/<skill-name>/` into `~/.claude/skills/<skill-name>`. Edits in the repo are immediately live.

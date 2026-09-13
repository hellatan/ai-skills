# ai-skills contributor instructions

This public repository contains reusable agent skills. Each skill lives in
`skills/<skill-name>/` and follows the SKILL.md convention with optional
`references/`, `scripts/`, and `assets/` directories.

Read [the Git workflow](docs/development/git-workflow.md) before changing the
repository. It is the project-specific authority for branches, commits, pushes,
pull requests, and releases. Do not rely on a personal global instruction file
for those rules.

## Lifecycle

- Start feature branches from `develop`; never commit work directly to `main`.
- Target pull requests at `develop` and wait for the repository's required
  checks before merge.
- A release is a `develop` to `main` pull request. release-please prepares the
  release PR and its merge creates the version tag.
- Keep public artifacts free of private paths, credentials, private repository
  names, and personal service identifiers.

## Project map

- `skills/<skill-name>/` — one package per skill.
- `scripts/install.sh` — installs selected skill directories into Claude and/or
  agent-neutral discovery roots. It records the explicit selection in this
  clone so Git hooks can repeat only that selection.
- `.githooks/` — non-blocking post-merge, post-checkout, and post-rewrite
  synchronization hooks.
- `scripts/validate.sh` — checks SKILL.md frontmatter and authored local
  Markdown references.
- `docs/architecture.html` — the living system map; update it when the
  components, flows, or failure modes change.

## Conventions

- Skill folder names are lowercase and hyphenated; frontmatter `name` matches
  the folder name. Descriptions name explicit trigger contexts so agents can
  discover the correct skill.
- Skills compose and each domain has one owner: test commands and steps are
  `testing-init`; CI job structure, workflows, and release-please are
  `gh-actions-init`; branches and protection are `gitflow-init`; hooks are
  `precommit-init`; generated project instructions are `claude-md-init`;
  `project-scaffold` and `release-workflow-init` orchestrate. Cross-reference
  the owner instead of duplicating its full procedure. The shared `checks` job
  is the deliberate seam: `gh-actions-init` owns the job and `testing-init`
  adds its unit-test step.
- A runnable bash block in a reference is shipped code. Extract the exact
  block, never a retyped approximation, and execute fixtures covering every
  verdict it can produce. This also applies to documentation-only edits.
- If a note below a code block says the block does something else, fix the
  block and remove the note. A caveat that cannot be encoded belongs above the
  block.

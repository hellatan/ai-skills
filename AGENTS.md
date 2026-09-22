# ai-skills contributor instructions

This public repository contains reusable agent skills. Each skill lives in
`skills/<skill-name>/` and follows the SKILL.md convention with optional
`references/`, `scripts/`, and `assets/` directories.

## Before working

- Cloud sessions load the shared workflow contract before other work: attach
  `<CONTRACT_REPOS>` yourself (in Claude Code cloud, with `add_repo`), one
  at a time since concurrent clones fail, then follow the contract
  repository's own cloud setup instructions before starting the task. If an
  attach is refused, say which and stop. Local sessions attach nothing and
  use the contract installed on the machine; if it is not installed there,
  say so before starting.
- Read [the Git workflow](docs/development/git-workflow.md) before changing
  the repository. It is the project-specific authority for branches,
  commits, pushes, pull requests, and releases. Do not rely on a personal
  global instruction file for those rules.

## Lifecycle

- Start feature branches from `develop`; never commit work directly to `main`.
- Target pull requests at `develop` and wait for the repository's required
  checks before merge.
- Use an explicit source and destination for the first push:
  `git push -u origin <local-branch>:<remote-branch>`.
- Before handing off a change, run `./scripts/validate.sh` and the focused
  fixture that covers any changed runnable reference or installer behavior.
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
- `scripts/validate.sh` — checks each skill's SKILL.md frontmatter only: the
  file exists, the frontmatter parses as a YAML mapping, `name` matches the
  folder name, and `description` is long enough to be a usable trigger. It
  does **not** resolve Markdown links or `assets/` and `references/` paths, so
  a green run is no evidence that a file a skill points at still exists.
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

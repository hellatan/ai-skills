# CONTRIBUTING.md

The human-facing counterpart to `CLAUDE.md`. Same conventions, different reader: `CLAUDE.md`
tells an agent how to work in the repo, `CONTRIBUTING.md` tells a person — including you in
six months, and anyone who picks the project up.

Owned here because a CONTRIBUTING is mostly branching, PR flow, and commit conventions —
this skill's domain. `project-scaffold` delegates to this file rather than carrying its own
copy.

## When to scaffold

- **Default-on** whenever gitflow is applied — the branch model is the thing it documents.
- Skip if `CONTRIBUTING.md` already exists (don't stomp a hand-written one). Offer to
  *extend* it instead if it's missing the branch/PR sections.
- GitHub surfaces it automatically from the repo root, `.github/`, or `docs/`. Prefer the
  **repo root** — most discoverable, and it's what the "Contributing guidelines" link on the
  new-issue/PR page points at.

## No org-wide shortcut for user accounts

A `.github` *organization* repo can supply a default CONTRIBUTING for every repo in the org.
That mechanism is **organizations only** — for a personal (user) account there is no
account-wide default, so each repo needs its own file. That's precisely why it belongs in a
scaffold: written once here, emitted consistently everywhere, instead of hand-copied and
drifting.

## Template

Fill the bracketed parts from the repo's actual setup — don't emit placeholders.

```markdown
# Contributing

## Branching

- Branch off `develop`, never `main`. (`main` only receives the promotion PR and releases.)
- Naming: `feature/<short-kebab-name>`, `fix/<short-kebab-name>`,
  `chore/<short-kebab-name>` for chores, refactors, docs, and CI.
- Never commit directly to `develop` or `main`, and never force-push either.

## Commits

Conventional commits are required — release-please derives the version bump and changelog
from them.

- `feat:` → minor bump `fix:` → patch bump
- `chore:` / `docs:` / `refactor:` / `test:` → no bump
- Breaking change: add `!` (`feat!:`) or a `BREAKING CHANGE:` footer → major bump

## Pull requests

- Open PRs against `develop`. Draft is fine until you want review.
- PR title follows conventional-commit format — it feeds the release notes.
- Include a **Summary** and a **Test plan** (checkbox list of how to verify).
- CI gates the merge. [List the checks this repo runs.]

## Running CI

- CI runs on PRs. It deliberately does **not** re-run on the post-merge push to `develop` —
  the PR already tested that code, and re-running it is duplicate billed minutes.
- To re-run CI, comment **`/rebuild`** on the PR, or use **Actions → CI → Run workflow**.
  Don't push an empty commit — that costs a whole fresh run.

## Local development

[Setup command, dev server, test command — pull these from package.json / pyproject.toml
rather than guessing.]

## Releases

Merging to `develop` opens a promotion PR to `main`. Merging that triggers release-please,
which opens a release PR; merging *that* tags the release.

⚠️ **Merge the `develop → main` promotion PR with "Create a merge commit" — never squash.**
Squashing rewrites `develop`'s commits into one new commit, so they stop being ancestors of
`main`: the branches diverge from a stale merge base, `git log main..develop` reports
already-released commits forever, and release-please can no longer see the `feat:`/`fix:`
messages it needs. Undoing it requires a force-push of `main`. GitHub's merge button
remembers the last method used, so check it before clicking.
```

## Notes

- **Keep it consistent with `CLAUDE.md`, don't duplicate it.** If the two disagree, a
  contributor and an agent will do different things. Cross-reference rather than restate:
  "conventions are in `CLAUDE.md`" is fine for detail that only agents need.
- **The `/rebuild` line matters.** It's the main discoverability path for that feature —
  someone who doesn't know it exists will never type it. Only include it if the repo
  actually has `rebuild.yml` (see
  `gh-actions-init/references/rebuild.md`).
- Don't document branch protection specifics that may not be enabled — free-tier private
  repos can't have it (see `branch-protection.md`).

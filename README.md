# ai-skills

Reusable project skills with agent-neutral project-instruction templates and
Claude Code compatibility, published as the `ht-skills` plugin.

## Skills

| Skill | Description |
|---|---|
| [project-scaffold](skills/project-scaffold) | Bootstrap a project with prescriptive defaults — Next.js / FastAPI, canonical AGENTS.md plus a Claude adapter, git workflow, pre-commit, GitHub Actions CI, release-please, and deploy stub. |
| [release-workflow-init](skills/release-workflow-init) | Bring the git + release workflow (gitflow branches + protection, release-please, trimmed CI) to a **bare or framework-less** repo — `git init` + private GitHub repo if needed, then orchestrates `gitflow-init` + `gh-actions-init`. The framework-less sibling of `project-scaffold`. |
| [testing-init](skills/testing-init) | Add a testing pipeline (Vitest / Playwright / pytest) + test stubs + scripts + optional CI test job to an existing project. |
| [gh-actions-init](skills/gh-actions-init) | Add `.github/workflows/` to an existing project — CI structure, release-please, deploy stub. |
| [gitflow-init](skills/gitflow-init) | Set up `main` + `develop` (+ optional `stage`), branch protection, and `develop` as the default branch on an existing repo. |
| [precommit-init](skills/precommit-init) | Add pre-commit hooks at the repo root, polyglot (Python / Node / fullstack). |
| [claude-md-init](skills/claude-md-init) | Write canonical per-stack AGENTS.md instructions and a thin Claude adapter to an existing project. The historical name remains compatible. |
| [architecture-doc-init](skills/architecture-doc-init) | Add a `docs/architecture.html` living system map to an existing repo — inline-SVG data-flow diagram, failure-modes table, key-files list, filled in with the repo's real components. |
| [ci-baseline-audit](skills/ci-baseline-audit) | Audit one or more repos for deviation from the CI baseline — duplicate `push` triggers, missing Playwright browser cache, missing `workflow_dispatch` or `/rebuild`, unexpected job names. Read-only by default. |
| [session-cleanup](skills/session-cleanup) | End-of-session pre-archive checklist — is the stated work verified done, is the git state clean, is a retrospective warranted, are there durable learnings worth saving. Reports a verdict; never acts without an explicit go. |
| [task-retrospective](skills/task-retrospective) | Generate a retrospective after a substantial task — failure signal and root causes, not just wins, plus action items and time calibration. |

## Install

### Development (symlinks, hot reload)

For working on the skills themselves — edits land instantly via the directory-watch mechanism in Claude Code.

```bash
git clone git@github.com:hellatan/ai-skills.git ~/projects/ai-skills
cd ~/projects/ai-skills
./scripts/install.sh
```

This preserves the legacy Claude-only default and symlinks each skill into
`~/.claude/skills/<skill-name>`. Select agent-neutral discovery or both roots
explicitly when needed:

```bash
./scripts/install.sh --target=agents  # ~/.agents/skills
./scripts/install.sh --target=both    # Claude and agent-neutral roots
```

The selection is saved in this clone and non-blocking Git hooks replay that
same selection. The installer never infers `both` from directories that happen
to exist, and it preserves unowned symlinks, files, directories, and hooks.

Opt in to repository hooks explicitly with `./scripts/install.sh --install-hooks`.
This avoids changing a custom or shared `core.hooksPath` by default. After an
opt-in, `git pull`, rebases, and branch switches re-sync the selected roots.

A hook run prints only what changed, and never fails the git operation. Re-running by hand is always safe:

```bash
./scripts/install.sh          # full output
./scripts/install.sh --quiet  # changes and warnings only
```

It never replaces an unowned symlink, file, directory, or hook. Owned stale
links are pruned only when their normalized target is exactly under this
checkout's `skills/` directory.

Note that a **linked worktree can't install** — `~/.claude/skills` has to point at the primary checkout, or `git worktree remove` would break every skill. Run it from `~/projects/ai-skills` instead.

### Plugin (for marketplace users)

Once published to the marketplace, users will install this as the `ht-skills` plugin. Plugin invocations are namespaced: `/ht-skills:project-scaffold`, `/ht-skills:testing-init`, etc.

To test the plugin loader locally without publishing:

```bash
claude --plugin-dir ~/projects/ai-skills
```

Note: the plugin loader caches `SKILL.md` content at session start. Use `/reload-plugins` after edits, or stick to the symlinked install above for active development.

## Adding a new skill

1. Branch off `develop`: `git checkout -b feat/<skill-name>`
2. Create `skills/<skill-name>/SKILL.md` (see Anthropic conventions in `CLAUDE.md`)
3. Run `./scripts/validate.sh` to confirm the SKILL.md is well-formed
4. Run `./scripts/install.sh --target=claude|agents|both` to symlink it locally
5. Test with Claude Code
6. Commit with `feat: add <skill-name> skill`, open PR to develop

## Updating an existing skill

Edit in place under `skills/<skill-name>/`. Symlink is already live, so changes show up immediately. Commit with `fix:` (bugfix) or `feat:` (new behavior).

## Plugin publishing

Submit the plugin to Anthropic's community marketplace via [clau.de/plugin-directory-submission](https://clau.de/plugin-directory-submission). Goes through automated security scanning + internal review. Plugin metadata lives at `.claude-plugin/plugin.json`.

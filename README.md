# ai-skills

Personal monorepo of Claude Code skills, published as the `ht-skills` plugin.

## Skills

| Skill | Description |
|---|---|
| [project-scaffold](skills/project-scaffold) | Bootstrap a new project with prescriptive defaults — Next.js / FastAPI, lean CLAUDE.md, git workflow, pre-commit, GitHub Actions CI, release-please, deploy stub. Orchestrates the init skills below for new projects. |
| [release-workflow-init](skills/release-workflow-init) | Bring the git + release workflow (gitflow branches + protection, release-please, trimmed CI) to a **bare or framework-less** repo — `git init` + private GitHub repo if needed, then orchestrates `gitflow-init` + `gh-actions-init`. The framework-less sibling of `project-scaffold`. |
| [testing-init](skills/testing-init) | Add a testing pipeline (Vitest / Playwright / pytest) + test stubs + scripts + optional CI test job to an existing project. |
| [gh-actions-init](skills/gh-actions-init) | Add `.github/workflows/` to an existing project — CI structure, release-please, deploy stub. |
| [gitflow-init](skills/gitflow-init) | Set up `main` + `develop` (+ optional `stage`), branch protection, and `develop` as the default branch on an existing repo. |
| [precommit-init](skills/precommit-init) | Add pre-commit hooks at the repo root, polyglot (Python / Node / fullstack). |
| [claude-md-init](skills/claude-md-init) | Write a per-stack CLAUDE.md to an existing project. |

## Install

### Development (symlinks, hot reload)

For working on the skills themselves — edits land instantly via the directory-watch mechanism in Claude Code.

```bash
git clone git@github.com:hellatan/ai-skills.git ~/projects/ai-skills
cd ~/projects/ai-skills
./scripts/install.sh
```

This symlinks each `skills/<skill-name>/` into `~/.claude/skills/<skill-name>`. Invocation is the bare skill name: `/project-scaffold`, `/testing-init`, etc.

It also installs `.githooks/{post-merge,post-checkout,post-rewrite}`, so **you only run this script once per clone**. After that, `git pull`, `git pull --rebase`, and branch switches re-sync the symlinks on their own: a new skill gets linked, and a renamed or deleted one gets its dead link pruned. Editing an existing skill never needed a re-run — the symlink makes those changes live immediately.

A hook run prints only what changed, and never fails the git operation. Re-running by hand is always safe:

```bash
./scripts/install.sh          # full output
./scripts/install.sh --quiet  # changes and warnings only
```

Two things it deliberately won't do: replace a real directory sitting where a symlink belongs, or remove a dangling link that points at some other repo. Both are reported with the `rm` command to run yourself.

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
4. Run `./scripts/install.sh` to symlink it locally
5. Test with Claude Code
6. Commit with `feat: add <skill-name> skill`, open PR to develop

## Updating an existing skill

Edit in place under `skills/<skill-name>/`. Symlink is already live, so changes show up immediately. Commit with `fix:` (bugfix) or `feat:` (new behavior).

## Plugin publishing

Submit the plugin to Anthropic's community marketplace via [clau.de/plugin-directory-submission](https://clau.de/plugin-directory-submission). Goes through automated security scanning + internal review. Plugin metadata lives at `.claude-plugin/plugin.json`.

# Agent-neutral migration scope

`AGENTS.md` is the canonical generated project instruction file. A root
`CLAUDE.md`, when needed for compatibility, is a thin adapter that points to it.
The shared Git workflow lives in `docs/development/git-workflow.md`; scoped
instruction files remain beside the code they govern.

The installer supports Claude, Codex, or both destinations and preserves
unowned files, links, directories, and hooks. Its tests use disposable fixtures
and never install into a developer's real home directory.

## Deliberately deferred

- The historical `claude-md-init` skill name and the Claude review-provider
  workflow remain for compatibility; this migration does not remove provider
  integrations.
- No agent-specific timing, approval, or personal-harness configuration is
  packaged. Runtime approval behavior remains the active harness's concern.
- Generated-project validation uses representative disposable fixtures. It does
  not create a live application or alter a user's repository.

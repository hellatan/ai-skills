# claude-code-review.yml — automated PR review

One file: `.github/workflows/claude-code-review.yml`. Runs
`anthropics/claude-code-action` against a PR's diff and posts inline findings.

Scaffold it whenever the repo takes PRs — which is every repo this skill
targets. It is independent of the release chain: nothing else depends on it,
and it depends on nothing but its own secret.

## The template

```yaml
name: claude-code-review

on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]

concurrency:
  group: claude-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  review:
    # Skip drafts, and skip the promotion/back-merge and release-please PRs.
    #
    # Drafts: `opened` fires for a PR opened as a draft, so without the
    # `draft == false` gate a draft is reviewed on open, again on every push
    # while it is still a draft, and once MORE on `ready_for_review` — that
    # last run against byte-identical code when no push happened in between.
    # The gate makes `ready_for_review` the FIRST review rather than a repeat
    # of the previous one. Reviewing a work-in-progress draft isn't wanted
    # anyway; that is what a local review pass is for.
    #
    # head_ref: a `develop → main` (or `stage → main`) promotion PR is by
    # construction already-reviewed code, and it re-fires on every
    # synchronize as the source branch advances. A release-please PR is
    # generated — a changelog and a version bump.
    if: >-
      github.event.pull_request.draft == false &&
      github.head_ref != 'develop' &&
      github.head_ref != 'main' &&
      !startsWith(github.head_ref, 'release-please')
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
      pull-requests: write
      issues: read
      id-token: write
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          track_progress: true
          prompt: |
            Review this pull request for real defects only: correctness bugs,
            logic errors, security vulnerabilities, data-loss risks, missing
            error handling, and broken behavior. Do NOT comment on style,
            naming, or formatting — <LINTERS> own those. Post inline
            comments on the specific lines; keep each finding concise and
            actionable. If the PR looks good, say so plainly.

            <REPO_SPECIFIC_CHECKS>
```

## Substitutions

| Placeholder | Fill with |
|---|---|
| `<LINTERS>` | the repo's actual linters — `ESLint and Prettier` (Node), `Ruff` (Python), `ESLint/Prettier and Ruff` (fullstack) |
| `<REPO_SPECIFIC_CHECKS>` | omit on a fresh scaffold; see below |

Add a `stage` exclusion to the `if:` **only when the repo has a `stage`
branch** — same condition that decides the staging release chain. It goes
**between the `develop` and `main` terms**, not at the end of the chain: the
last term carries no trailing `&&`, so appending there produces a dangling
operator and an invalid expression.

```yaml
      github.event.pull_request.draft == false &&
      github.head_ref != 'develop' &&
      github.head_ref != 'stage' &&
      github.head_ref != 'main' &&
      !startsWith(github.head_ref, 'release-please')
```

### Repo-specific checks

On a fresh scaffold there is nothing to say yet, so leave the block out
entirely rather than inventing rules. It earns its place later, once the repo
has invariants a general reviewer can't infer from the diff — a migration that
must accompany a schema edit, a persistence pattern new code has to follow, a
caching layer that breaks quietly. Add them as a short bulleted
"Repo-specific checks (high priority)" list appended to the prompt.

## The `draft == false` gate is the point

Without it the action runs on every draft push. That is the same
duplicate-work shape as running CI on both the PR and the post-merge push:
it is not wrong, it is just paid for repeatedly and the last payment buys
nothing.

The trade is real and worth stating in the report: **no automated review
happens while a PR is a draft.** For a workflow where PRs are opened as
drafts by default, that means the bot's review arrives when the PR is marked
ready, not before. Drafting is the author's own review window.

There is no on-demand escape hatch unless the repo also has a `claude.yml`
(the `@claude` mention-triggered workflow). This skill does not scaffold one —
a mention trigger fires on `issue_comment`, which is a different security
surface and a different decision. If someone wants review during drafting,
that is the file to add.

## Credential

`CLAUDE_CODE_OAUTH_TOKEN` — a **repo secret**, per repo.

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo>
```

Severity is **🔴 loud**: with the secret missing, the workflow still triggers
and the job fails on the action step. That is a red X on every PR rather than
a quietly absent review, so it announces itself — but it announces itself as
a broken check, which reads like a CI failure. Not silent (nothing hides it)
and not blocking (nothing downstream depends on it). Flag it in the report as
a post-scaffold action.

Nothing else depends on this workflow. A repo that never sets the secret can
delete the file and lose nothing but the review.

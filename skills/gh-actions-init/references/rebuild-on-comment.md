# /rebuild on comment

A ChatOps re-trigger: commenting `/rebuild` on a PR re-runs its failed CI (or kicks off CI fresh when none ran). Companion to `release-please.md` and `develop-to-main-pr.md`.

## Why this exists

GitHub does not fire workflows for events created by the default `GITHUB_TOKEN` (its guard against recursive Actions loops), and runs on PRs authored by `github-actions[bot]` sit in `action_required` waiting for a manual approval click. The root fix — wired in by default via the `RELEASE_PLEASE_TOKEN` PAT in `release-please.yml` and `develop-to-main-pr.yml` (see `release-please.md`) — is to author those PRs as a real user. This workflow is the universal manual fallback: re-run CI from any PR with a single comment, covering flaky runs, repos where the secret isn't set up yet, or an expired PAT.

## Why `GITHUB_TOKEN` is correct here (not the PAT)

Unlike `release-please.yml` and `develop-to-main-pr.yml` — which **author** PRs and so need the `RELEASE_PLEASE_TOKEN` PAT to dodge the bot-PR CI gap — this workflow stays on the built-in `GITHUB_TOKEN` **by design**. It's not a downgrade:

- It re-triggers CI two ways, **both exempt from the recursion guard**. `gh run rerun` re-runs an *existing* run — reruns are not recursion-blocked. The no-prior-run fallback `gh workflow run` is a **`workflow_dispatch`** event, and per [GitHub's docs](https://docs.github.com/en/actions/concepts/workflows-and-actions/about-workflows) `workflow_dispatch` and `repository_dispatch` are the explicit **exceptions** to the rule that `GITHUB_TOKEN`-created events don't start new runs. So a `GITHUB_TOKEN`-issued `workflow_dispatch` *does* start the run.
- A PAT here adds **no capability** — both paths already work with `GITHUB_TOKEN` — while widening blast radius (the PAT's broader scopes on a workflow any trusted commenter can fire) and burning the personal token's rate limit on every `/rebuild`.

So: PAT for the two PR-**authoring** workflows, `GITHUB_TOKEN` for this **re-trigger** one. (This pre-empts the recurring "shouldn't this be the PAT too?" question — it shouldn't.)

## When to scaffold

- **Default-on for gitflow repos** (those with a `develop` branch) — that's where the bot-PR flows exist.
- Skip for `main`-only repos (no bot-PR gap to cover).
- The file must live on the **default branch** (`develop`) to be active, since `issue_comment` workflows only run from the default branch.
- Skip if `.github/workflows/ci-rebuild-on-comment.yml` already exists.

## Security

- Restricted to trusted commenters via `author_association` ∈ {OWNER, MEMBER, COLLABORATOR}, so outside contributors can't trigger it.
- It **never checks out PR-head code** — it only calls `gh run rerun` / `gh workflow run`, so there is no code-execution ("pwn request") vector despite running with repo secrets.
- A prefix-command gate (the comment must *begin* with `/rebuild` as a whole word) stops prose that merely mentions `/rebuild` from firing a build.

## Command matching

The gate matches `^/rebuild` as a **whole word**, so trailing prose is fine:

| Comment | Fires? |
| --- | --- |
| `/rebuild` | ✅ |
| `/rebuild please` / `/rebuild — flaky e2e` | ✅ trailing prose is allowed |
| `/rebuilding the docs` | ❌ word boundary fails |
| `should I /rebuild this?` | ❌ doesn't start the job at all |

Deliberately **not** an exact-body match. Requiring the body to equal `/rebuild` exactly
meant a comment like `/rebuild please` started the job, failed the gate, and exited with
nothing visible on the PR — a silent no-op for someone plainly asking for a rebuild.
Accepting the prefix removes that failure mode entirely (and one round trip) instead of
papering over it with an explanatory reply.

Two implementation notes:

- `[^a-zA-Z0-9_]|$` emulates a `\b` word boundary — bash's ERE has no `\b`.
- `${trimmed,,}` lowercases for a case-insensitive match, but the **job-level** `if` still
  uses a case-sensitive `startsWith`, so `/Rebuild` never starts the job. GitHub
  expressions have no regex or lowercase function, and loosening that filter would start
  billable jobs on looser matches. Lowercase `/rebuild` is the real-world case.

## Workflow

`.github/workflows/ci-rebuild-on-comment.yml`:

```yaml
name: CI rebuild on comment

on:
  issue_comment:
    types: [created]

permissions:
  actions: write          # rerun / dispatch workflow runs
  contents: read
  pull-requests: write    # post the result comment
  issues: write           # 👀 reaction (PR comments use the issues reactions endpoint)

concurrency:
  group: rebuild-${{ github.event.issue.number }}
  cancel-in-progress: false

jobs:
  rebuild:
    if: >
      github.event.issue.pull_request &&
      contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association) &&
      startsWith(github.event.comment.body, '/rebuild')
    runs-on: ubuntu-latest
    steps:
      - name: Enforce command match
        id: gate
        env:
          BODY: ${{ github.event.comment.body }}
        run: |
          trimmed="$(printf '%s' "$BODY" | tr -d '\r' | sed -e 's/^[[:space:]]*//')"
          if [[ "${trimmed,,}" =~ ^/rebuild([^a-zA-Z0-9_]|$) ]]; then
            echo "ok=true" >> "$GITHUB_OUTPUT"
          else
            echo "ok=false" >> "$GITHUB_OUTPUT"
            echo "Comment began with '/rebuild' but not as a whole word — ignoring."
          fi

      - name: Acknowledge with 👀
        if: steps.gate.outputs.ok == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh api repos/${{ github.repository }}/issues/comments/${{ github.event.comment.id }}/reactions -f content=eyes

      - name: Re-run failed CI (or dispatch if nothing ran)
        if: steps.gate.outputs.ok == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR: ${{ github.event.issue.number }}
        run: |
          head="$(gh pr view "$PR" --json headRefName -q .headRefName)"
          mapfile -t ids < <(gh run list --branch "$head" --limit 20 \
            --json databaseId,status,conclusion \
            -q '.[] | select(.status!="in_progress" and (.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out")) | .databaseId')
          if [[ ${#ids[@]} -gt 0 ]]; then
            for id in "${ids[@]}"; do gh run rerun "$id" --failed || gh run rerun "$id"; done
            gh pr comment "$PR" --body "🚀 Re-running ${#ids[@]} failed/cancelled run(s) for \`$head\`."
          else
            gh workflow run ci.yml --ref "$head"
            gh pr comment "$PR" --body "🚀 No prior run to re-run — dispatched \`ci.yml\` on \`$head\`."
          fi
```

**Adapt the dispatch fallback** (`gh workflow run ci.yml`) to the repo's actual CI workflow filename if it isn't `ci.yml` (e.g. a docs/skills repo whose CI is `validate.yml`). The target workflow must have `workflow_dispatch:` in its `on:` block (see `ci-structure.md`).

## Notes for the report

- Lives on `develop` (default branch) to be active.
- Pairs with the PAT setup: the `RELEASE_PLEASE_TOKEN` PAT fixes bot-PR CI automatically (and is scaffolded in by default); `/rebuild` is the manual fallback for any red/missing run.

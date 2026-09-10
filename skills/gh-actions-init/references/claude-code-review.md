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

## A finished review is silent — push the verdict

The action posts its findings as a `claude[bot]` comment and the run ends.
Nothing pushes anywhere. The only way to learn a review finished is to sit on
the PR page, so in practice every PR ends with a human asking someone to go
watch it — and the check going green tells you the *job* succeeded, not that
there is nothing to fix.

Append these two steps to the `review` job (they need `id: claude` on the
action step, and the `actions/checkout` that is already step 1, because the
alert re-uses `./.github/actions/discord-alert`):

```yaml
      # ---------------------------------------------------------------------
      # A finished review is SILENT. The action posts its findings as a
      # claude[bot] comment and the run ends; nothing pushes anywhere, so the
      # only way to learn the review finished is to sit on the PR page —
      # which is why every PR ends with a human asking someone to watch it.
      #
      # This fires on EVERY completed review, clean ones included, and that is
      # deliberate. The verdict lives in model-written prose with no
      # structured field behind it, so a clean/findings classifier would be a
      # guess — and when it guessed wrong it would fail SILENTLY: no alert on
      # a PR that has real findings, which is indistinguishable from a quiet
      # week. Quoting the comment's tail instead can only ever be unhelpful,
      # never wrong. One message per review is the price of never missing one.
      # ---------------------------------------------------------------------
      - name: Collect the review verdict
        id: verdict
        if: always()
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          PR: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          REVIEW_OUTCOME: ${{ steps.claude.outcome }}
        shell: bash
        run: |
          set -uo pipefail

          err=$(mktemp)

          # --paginate --slurp because the review comment is the NEWEST one: a
          # single unpaginated page returns the OLDEST 30, so on a busy PR the
          # alert would quote a stale review as if it were this one.
          # rc is captured separately from emptiness on purpose — a failed
          # lookup and a PR with no comment both yield an empty string, and
          # conflating them reports "the review posted nothing" when the truth
          # is "we could not ask".
          comments=$(gh api --paginate --slurp \
            "repos/${REPO}/issues/${PR}/comments?per_page=100" 2>"$err")
          rc=$?

          if [ "$rc" -ne 0 ]; then
            state="lookup-failed"
          else
            sel='[.[] | select(.user.login == "claude[bot]")] | sort_by(.created_at) | last'
            body=$(printf '%s' "$comments" | jq -r "flatten | (${sel}) // {} | .body // \"\"")
            url=$(printf '%s' "$comments"  | jq -r "flatten | (${sel}) // {} | .html_url // \"\"")
            if [ -n "$body" ]; then state="reviewed"; else state="no-comment"; fi
          fi

          case "$state" in
            reviewed)
              # The verdict lives at the END of the comment: track_progress
              # opens it with a checklist, so a head slice shows checkboxes
              # and never a finding.
              if [ "${#body}" -gt 1200 ]; then
                excerpt="…${body: -1200}"
              else
                excerpt="$body"
              fi
              title="Claude review finished · ${REPO}#${PR}"
              color=3066993
              detail="**${PR_TITLE}**"$'\n\n'"${excerpt}"$'\n\n'"[Read the full review](${url})"
              ;;
            no-comment)
              title="⚠️ Claude review posted nothing · ${REPO}#${PR}"
              color=16098851
              detail="**${PR_TITLE}**"$'\n\n'"The review job finished but posted no comment. Editing \`claude-code-review.yml\` itself makes the action warn-and-skip while still reporting success, so read the run log — do NOT read the green check as proof the review ran."$'\n\n'"[Run log](${RUN_URL})"
              ;;
            lookup-failed)
              title="🚫 Claude review verdict unreadable · ${REPO}#${PR}"
              color=15158332
              detail="**${PR_TITLE}**"$'\n\n'"Could not read this PR's comments (\`gh api\` exit ${rc}). The review may or may not have run."$'\n\n'"\`\`\`"$'\n'"$(head -c 400 "$err")"$'\n'"\`\`\`"$'\n\n'"[Run log](${RUN_URL})"
              ;;
          esac

          if [ "$REVIEW_OUTCOME" != "success" ]; then
            title="🚫 Claude review step ${REVIEW_OUTCOME} · ${REPO}#${PR}"
            color=15158332
            detail="⚠️ The review step itself reported \`${REVIEW_OUTCOME}\` — treat any verdict below as incomplete."$'\n\n'"${detail}"
          fi

          # Random delimiter: the body is model-written text that can contain
          # any literal line, a fixed "EOF" included.
          delim="EOF_$(openssl rand -hex 8)"
          {
            printf 'title=%s\n' "$title"
            printf 'color=%s\n' "$color"
            printf 'description<<%s\n' "$delim"
            printf '%s\n' "$detail"
            printf '%s\n' "$delim"
          } >> "$GITHUB_OUTPUT"

      - name: Push the verdict to the PR channel
        if: always()
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<PR_ALERT_WEBHOOK_SECRET> }}
          title: ${{ steps.verdict.outputs.title }}
          description: ${{ steps.verdict.outputs.description }}
          color: ${{ steps.verdict.outputs.color }}
```

Substitute `<PR_ALERT_WEBHOOK_SECRET>` with the repo's PR-channel secret
(default `DISCORD_PR_ALERTS_WEBHOOK`) — the **PR** channel, not the errors
one: a review waiting to be read is a thing waiting on a human, not an
outage. See `references/main-to-develop-backmerge.md` for that split. With no
webhook set the composite writes the verdict to the run summary and warns, so
the step is safe to scaffold before the secret exists.

### Why it alerts on clean reviews too

The verdict lives in model-written prose. There is no structured field behind
it, so classifying clean-vs-findings would be a guess — and a wrong guess
fails **silently**: no alert on a PR that has real findings, which is
indistinguishable from a quiet week. Quoting the comment's tail can only ever
be unhelpful, never wrong. One message per review is the price of never
missing one.

`--json-schema` in `claude_args` would give a real structured verdict via the
action's `structured_output`. Its plumbing is mode-independent in the action's
shared entrypoint, but it is **untested under tag mode**, which
`track_progress: true` forces — and its failure mode is the silent one above.
Do not reach for it without a live tag-mode run proving it populates.

### The tail slice, not the head

`track_progress: true` opens the comment with a progress checklist. A head
slice shows checkboxes and never a finding; the verdict is the last thing
written. Hence `${body: -1200}`.

### This step cannot be verified on the PR that adds it

`claude-code-action` validates the workflow against the repo's **default
branch** and warn-and-skips when it differs — so on the PR that adds or edits
`claude-code-review.yml`, the job reports success while the action never runs
and posts no comment. That is exactly the `no-comment` branch: it alerts
amber and says to read the run log rather than trusting the green check.

The first real proof is the **next** PR after this one merges. Verify the
shell before merging instead — parse the file, pull the `run:` block out of
the parsed YAML (never `sed`: a `|` block scalar strips the common indent, so
addresses copied from the `.yml` match nothing), and run it against fixtures
covering all four terminal states: a real review comment, no comment, a
lookup failure, and the action step itself failing.

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

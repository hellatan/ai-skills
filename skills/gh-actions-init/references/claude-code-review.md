# claude-code-review.yml — automated PR review

One file: `.github/workflows/claude-code-review.yml`. Runs
`anthropics/claude-code-action` against a PR's diff and posts inline findings.

Scaffold it whenever the repo takes PRs — which is every repo this skill
targets. It is independent of the release chain: nothing else depends on it.
Its own dependencies are its `CLAUDE_CODE_OAUTH_TOKEN` secret and — for the
verdict-alert steps below — the `.github/actions/discord-alert` composite.

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
    # The review cap lives on the ACTION STEP below, not here. A job-level
    # timeout CANCELS the job, `!cancelled()` then skips the verdict-alert
    # steps appended later (§ "A finished review is silent"), and a hung
    # review alerts nothing — the exact silence those steps exist to
    # eliminate. A step-level timeout fails the STEP instead, so
    # `steps.claude.outcome` is `failure` and the verdict step still posts
    # the red embed. This job cap is only the backstop; it must clear the
    # step cap with room for every OTHER step (checkout, verdict lookup,
    # alert) or it still wins the race and cancels — 20/15 leaves five
    # minutes for steps that take seconds. Before the verdict steps are
    # appended the split buys nothing, but costs nothing either.
    timeout-minutes: 20
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
        timeout-minutes: 15
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

Append these two steps to the `review` job. They need `id: claude` on the
action step (shown), the `actions/checkout` that is already step 1, and the
`.github/actions/discord-alert` composite:

```yaml
      # `id:` is load-bearing — the verdict step reads
      # `steps.claude.outcome`. Without it the expression resolves to an
      # empty string, not to a failure.
      - uses: anthropics/claude-code-action@v1
        id: claude
        timeout-minutes: 15
        with:
          # …unchanged…

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
      #
      # `!cancelled()`, NOT `always()`: this job runs under
      # cancel-in-progress, and `synchronize` is in the trigger list, so a
      # fixup pushed mid-review cancels the run in flight. `always()` alerts
      # on those too — a red false alarm per fixup push, which is how a
      # channel gets muted. `!cancelled()` still covers a failed or skipped
      # review step, which are the states worth hearing about.
      # ---------------------------------------------------------------------
      - name: Collect the review verdict
        id: verdict
        if: ${{ !cancelled() }}
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          PR: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          RUN_ID: ${{ github.run_id }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
          REVIEW_OUTCOME: ${{ steps.claude.outcome }}
        shell: bash
        run: |
          set -uo pipefail

          err=$(mktemp)

          # --paginate --slurp because the comment we want is the NEWEST one: a
          # single unpaginated page returns the OLDEST 30. --slurp emits an
          # array PER PAGE, hence the `flatten` below.
          # rc is captured separately from emptiness on purpose — a failed
          # lookup and a PR with no comment both yield an empty string, and
          # conflating them reports "the review posted nothing" when the truth
          # is "we could not ask". The same care is owed to jq: a parse error
          # also yields empty, so its status is checked too.
          comments=$(gh api --paginate --slurp \
            "repos/${REPO}/issues/${PR}/comments?per_page=100" 2>"$err")
          rc=$?
          why="gh api exited ${rc}"

          if [ "$rc" -eq 0 ]; then
            # Scoped to THIS run, not merely to the newest bot comment.
            # track_progress posts a fresh comment per run, so a PR reviewed
            # once already has one: an unscoped selector would find it, and a
            # run that posted nothing (see the warn-and-skip note below) would
            # report GREEN quoting a previous run's verdict about a previous
            # diff. Every comment opens with a `[View job](…/actions/runs/ID)`
            # link, which keys it to its own run.
            # shellcheck disable=SC2016  # $rid is a jq variable, bound by --arg
            sel='[.[] | select(.user.login == "claude[bot]")
                      | select(.body | contains($rid))] | sort_by(.created_at) | last'
            body=$(printf '%s' "$comments" \
              | jq -r --arg rid "/actions/runs/${RUN_ID}" "flatten | (${sel}) // {} | .body // \"\"" 2>"$err")
            jq_rc=$?
            url=$(printf '%s' "$comments" \
              | jq -r --arg rid "/actions/runs/${RUN_ID}" "flatten | (${sel}) // {} | .html_url // \"\"" 2>>"$err")
            url_rc=$?
            # BOTH jq statuses matter: an url-extraction CRASH discarded here
            # would build a green embed from half-read data. Distinct from an
            # EMPTY url — jq exits 0 on a null/absent field via `// ""` —
            # which the `reviewed` branch below handles.
            if [ "$jq_rc" -ne 0 ] || [ "$url_rc" -ne 0 ]; then
              rc=1; why="jq exited body=${jq_rc} url=${url_rc}"
            fi
          fi

          if [ "$rc" -ne 0 ]; then
            state="lookup-failed"
          elif [ -n "$body" ]; then
            state="reviewed"
          else
            state="no-comment"
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
              # url can be EMPTY with jq exiting 0 (`.html_url // ""` on a
              # null/absent field is not a crash). Never ship a dead
              # `[Read the full review]()` link — fall back to the run log.
              if [ -z "$url" ]; then
                url="$RUN_URL"
              fi
              title="Claude review finished · ${REPO}#${PR}"
              color=3066993
              detail="**${PR_TITLE}**"$'\n\n'"${excerpt}"$'\n\n'"[Read the full review](${url})"
              ;;
            no-comment)
              title="⚠️ Claude review posted nothing · ${REPO}#${PR}"
              color=15105570
              detail="**${PR_TITLE}**"$'\n\n'"This run posted no review comment. Editing \`claude-code-review.yml\` itself makes the action warn-and-skip while still reporting success, so read the run log — do NOT read the green check as proof the review ran."$'\n\n'"[Run log](${RUN_URL})"
              ;;
            lookup-failed)
              title="🚫 Claude review verdict unreadable · ${REPO}#${PR}"
              color=15158332
              detail="**${PR_TITLE}**"$'\n\n'"Could not read this PR's comments (${why}). The review may or may not have run."$'\n\n'"\`\`\`"$'\n'"$(head -c 400 "$err" | tr -d '\`')"$'\n'"\`\`\`"$'\n\n'"[Run log](${RUN_URL})"
              ;;
          esac

          # An EMPTY outcome is not a failure, it is a missing `id: claude` on
          # the action step — the expression resolves to "" and a plain
          # `!= success` test would red-alarm every clean review with a blank
          # verb. Name the actual cause instead.
          if [ -z "$REVIEW_OUTCOME" ]; then
            title="🚫 Claude review outcome unavailable · ${REPO}#${PR}"
            color=15158332
            detail="\`steps.claude.outcome\` resolved to empty — the \`anthropics/claude-code-action\` step is missing \`id: claude\`."$'\n\n'"${detail}"
          elif [ "$REVIEW_OUTCOME" != "success" ]; then
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
        if: ${{ !cancelled() }}
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<PR_ALERT_WEBHOOK_SECRET> }}
          # `||` fallbacks: if the verdict step itself crashed (a `set -u`
          # trip, a missing binary), its outputs are empty strings, and the
          # alert goes out blank at best — an unreadable embed announcing
          # nothing, precisely when the alert pipeline itself broke. The
          # fallbacks keep that failure legible in the channel.
          title: ${{ steps.verdict.outputs.title || 'Claude review verdict step crashed' }}
          description: ${{ steps.verdict.outputs.description || 'The verdict step itself failed before writing its outputs — read the run log.' }}
          color: ${{ steps.verdict.outputs.color }}
```

`discord-alert` is scaffolded by `references/release-verification.md`, which
runs only alongside release-please. **If verification wasn't scaffolded, add
the composite alongside this workflow or drop these two steps** — referencing
an action that doesn't exist fails the run on the missing action instead of
alerting, and `!cancelled()` guarantees that red X on every PR, including ones
where everything else passed.

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
action's `structured_output`. Its plumbing looks mode-independent — `run.ts`
sets the output unconditionally from `claudeResult.structuredOutput`, in the
same entrypoint every mode goes through (read at `v1`, 2026-09-10) — but the
vendor's own coverage (`.github/workflows/test-structured-output.yml`)
exercises `base-action`, **never tag mode**, which `track_progress: true`
forces (`src/modes/detector.ts`). Its failure mode is the silent one above.
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
covering every terminal state:

| Fixture | Expected |
|---|---|
| a comment carrying **this** run's id | green, quoting its tail |
| a comment carrying only an **older** run's id | amber — never green on a stale verdict |
| both, newest first | green, quoting **this** run's |
| no comments at all | amber |
| `gh` exits non-zero | red, naming the exit code |
| `gh` exits 0 with non-JSON | red — a `jq` parse error is not "posted nothing" |
| the `.html_url` extraction alone exits non-zero | red — a dead link never ships inside a green embed |
| a comment whose `html_url` is null or absent | green — the link falls back to the run log, never `()` |
| `REVIEW_OUTCOME` empty | red, naming the missing `id: claude` |
| `REVIEW_OUTCOME=failure` | red, verdict marked incomplete |

The last five are the ones a four-state list misses, and each is a state
where an earlier draft of this step reported the wrong colour or shipped a
dead link — the url ones shipped in a downstream repo before a fresh-context
review caught that the extraction's exit status was simply discarded. Prove
each fixture load-bearing by mutating the code it covers — dropping the
`contains($rid)` filter must turn the stale-comment case green, reverting the
`url_rc` capture must turn the dead-link case green, and deleting the
empty-url fallback must put a literal `[Read the full review]()` back in the
null-`html_url` case.

Two of the hardenings above are not reachable by these shell fixtures at all:
the step-level `timeout-minutes` (an envelope property — no `run:` block test
can observe where a cap lives) and the `||` fallbacks on the Discord step's
inputs (GitHub expressions, evaluated by the runner). Reading the parsed YAML
confirms only their **shape**. The behavioural premise — a step-level timeout
fails the step with `steps.<id>.outcome = failure` while `cancelled()` stays
false, so the alert steps still run — is the runner's documented behaviour,
but the first thing that actually observes it is a live timed-out run: the
same class of claim as this section's heading — unverifiable until a later
run supplies the event.

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

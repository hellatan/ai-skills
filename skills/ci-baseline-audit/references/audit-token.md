# The audit token

The credential the scheduled audit reads other repos with. Its **value** lives only in the
private host repo's secrets; the setup below is generic and belongs here.

## What it needs

A **fine-grained PAT**, read-only:

| Setting | Value |
| --- | --- |
| Resource owner | the account that owns the audited repos |
| Repository access | All repositories (discovery mode) or the selected set (list mode) |
| Repository permissions | **Metadata: Read-only** + **Contents: Read-only** (+ **Secrets: Read-only** for checks 10 and 13) |
| Expiration | note the date — see "when it expires" below |

**Contents: Read** is what fetches `.github/workflows/*`. **Metadata: Read** is mandatory
on any fine-grained PAT.

**Secrets: Read-only** is needed by **check 10** (referenced secrets exist) and **check 13**
(`CLAUDE_CODE_OAUTH_TOKEN` is set), and nothing else. It grants the secret **names** only — values are never retrievable through the API at
any permission level, so this does not put a credential within the audit's reach. It is
still a read permission, so it doesn't break the no-write rule below.

If you'd rather not grant it, that's a legitimate choice — but then check 10 and check 13's
secret part must report `skipped: token lacks Secrets:Read` on every repo. They must
**never** report a pass they couldn't verify; see `checks.md` checks 10 and 13. Check 13's
workflow-file parts (presence, draft gate) are unaffected and still run.

**No write permission, ever.** An audit must not be able to change what it audits. If a
proposed change appears to need write access, the change is wrong — report the finding and
let a human (or the owning skill) make the edit through a PR.

`GITHUB_TOKEN` cannot substitute: it is scoped to the repo running the workflow and cannot
read the other repos.

Add it to the **host repo** only:

```bash
gh secret set AUDIT_TOKEN --repo <owner>/<host-repo>
```

## Diagnosing "repo not found"

**GitHub returns 404, not 403, for a private repo a token cannot see** — deliberately, so a
token can't be used to probe which private repos exist. Every access problem therefore
looks identical to "the repo was deleted", and the audit reporting `N/N repos could not be
audited` tells you nothing on its own.

Two facts that make this harder than it looks, both learned the hard way:

1. **`gh api user` succeeding proves identity, not authority.** A token with zero
   permissions authenticates perfectly and 404s every repo call.
2. **A fine-grained PAT always authenticates as its _creator_.** So "authenticated as
   `alice`" does **not** confirm the token's **resource owner** is `alice`. Reading that as
   confirmation sends you looking in the wrong place.

So the useful question is not "is the token valid" but **"what can it see":**

```bash
# how many repos does this token actually have access to?
GH_TOKEN=<token> gh api "user/repos?per_page=100&affiliation=owner,collaborator,organization_member" \
  --jq '.[].full_name' | wc -l
```

| Result | Diagnosis |
| --- | --- |
| **0 repos** | The token grants no repository access at all — see the confirmed cause below |
| **N repos, but not the one you want** | Access works; that repo simply isn't in the selection. Add it, or switch to All repositories |

Bake this into the runner as a preflight: authenticate, probe one repo, and on failure
report the login **and** the visible-repo count. One extra API call turns a guessing game
into a single answer.

## Confirmed cause: a token with nothing granted

The most likely cause, and the one actually hit in practice:

> **Repository access:** "This token does not have access to any repositories."
> **Repository permissions:** "This token does not have any repository permissions."

GitHub's fine-grained PAT creation flow puts *Repository access* and *Repository
permissions* in separate sections below the name and expiry fields. **You can click
"Generate token" without touching either** — producing a token that is valid, authenticates
cleanly, and can do absolutely nothing. Nothing in the creation flow warns you.

Check the token's own settings page first; it states both plainly.

Worth recording what it was **not**: the resource owner was correct. Resource owner is a
real trap (and worth checking), but "authenticated as the right user" led to that theory and
it was wrong. Check what the token can *see* before theorising about *why*.

## Fixing it

Edit the token → set Repository access → set Repository permissions → save.

**Editing access or permissions does not change the token value**, so the stored secret keeps
working — no re-paste needed. Only the "Regenerate token" button issues a new value.

## When it expires

Fine-grained PATs expire (≤1 year). On expiry the audit fails its preflight and alerts, so
the failure is loud rather than silent — but the audit stops running until it's renewed.

Renewal is the one moment the secret *does* need re-pasting: a regenerated token is a new
value.

## Related

- `repo-list.md` — token scope and repo-resolution mode must match; a selected-repos token
  with discovery mode looks automatic but silently isn't
- `gh-actions-init/references/release-please.md` — the other PAT in this system
  (`RELEASE_PLEASE_TOKEN`), which *does* need write access because it authors PRs

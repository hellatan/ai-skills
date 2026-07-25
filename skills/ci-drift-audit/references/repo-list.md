# Which repos get audited

Where the audited set comes from, and where an adopter keeps it. The skill itself never
contains repo names — it's public, and repo lists are not.

## The audit host repo

Everything below lives in **one private repo you nominate as the audit host** — the repo
whose Actions run the schedule and whose secrets hold the token. It is not a special kind
of repo and nothing needs creating from scratch if you already have a candidate:

- an existing private ops / infra / automation repo (most common — the audit is a few files
  in `.github/`, it doesn't take the repo over)
- a personal "workspace" or hub repo you already keep active
- failing those, a new private repo — name it something obvious like `ci-audit`

Two requirements, both hard:

1. **Private.** The repo list names your private repos, drift reports describe their CI, and
   the token can read them. See the "Where the audit runs" section in `SKILL.md`.
2. **Active enough to keep running.** Scheduled workflows are auto-disabled after **60 days
   of no repository activity** — but that rule applies to **public** repos, so a private
   host is not at risk from inactivity. It *is* still worth picking a repo you'd notice
   breaking.

One host audits many repos. You do not put anything in the audited repos themselves — they
stay untouched, which is what keeps this read-only.

## Conventional paths

In the private host repo:

```
.github/ci-drift-audit/
  repos.txt     # explicit list mode (optional if using discovery)
  ignore.txt    # exclusions, applied in BOTH modes (optional)
  audit.sh      # the runner
```

Prescribed rather than suggested: a convention means anyone adopting the skill puts the
file where the next reader expects it, and the runner needs no configuration to find it.

Format for both `.txt` files — one `owner/repo` per line, blank lines ignored, `#` to end
of line is a comment:

```
hellatan/example-app        # why it's in the list
# hellatan/paused-repo      # temporarily disabled: reason
```

## Mode 1: discovery (recommended default)

Enumerate what the token can see, subtract `ignore.txt`:

```bash
gh repo list "$OWNER" --limit 200 --no-archived --source \
  --json nameWithOwner -q '.[].nameWithOwner' \
  | grep -vxFf <(grep -oE '^[^#]*' ignore.txt | tr -d '[:blank:]' | grep .) -
```

- `--no-archived` skips archived repos — they can't drift, and alerting on them is pure
  noise.
- `--source` excludes forks, whose CI you don't control.
- Consider also skipping repos with no `.github/workflows/` — nothing to audit, and they'd
  otherwise fill the report with `skipped`.

**Why this is the default:** a hand-maintained list only covers what you remembered to add.
A repo created six months from now is never audited, nothing says so, and the report still
reads "all green" — coverage silently shrinks relative to the fleet. Discovery makes new
repos opt-*out* instead of opt-*in*.

**Token caveat — match the token scope to the mode.** Discovery is bounded by what the
token can enumerate, which makes one combination quietly broken:

| Token scope | Repo source | Verdict |
| --- | --- | --- |
| All repositories (read-only) | discovery | ✅ new repos covered automatically |
| Selected repositories | explicit `repos.txt` | ✅ both narrow; the set is visible in git |
| Selected repositories | discovery | ⚠️ **looks automatic, silently isn't** |

In that third row, a repo created after the token was issued isn't in its scope, so
discovery never returns it and it goes unaudited with no signal. That's the failure
discovery exists to prevent, relocated from a file in version control to a setting in the
GitHub UI — strictly worse, because nobody reviews token scope in a PR.

Pick a coherent pair. If you want discovery's "new repos are opt-out" property, the token
needs **all repositories** with read-only Contents + Metadata. If you'd rather keep the
token narrow, use explicit-list mode so the audited set at least stays reviewable.

Verify enumeration before relying on it — don't assume:

```bash
GH_TOKEN=<the-audit-token> gh repo list <owner> --limit 200 --json nameWithOwner \
  -q '.[].nameWithOwner' | wc -l
```

If that returns fewer repos than expected (or zero), the token can't enumerate and
discovery mode will silently under-report.

## Mode 2: explicit list

Read `repos.txt`, subtract `ignore.txt`. Use when:

- the audited set is deliberately narrow (a pilot, or a few flagship repos)
- it spans **multiple owners** or orgs, which a single `gh repo list <owner>` won't cover
- the token can't enumerate (see caveat above)
- you want the audited set reviewable in a PR

The cost is the maintenance burden above — so if you pick this mode, put a line in the
host repo's `CONTRIBUTING.md` telling people to add new repos here.

## Newly scaffolded repos

A repo created by `project-scaffold` has to become visible to the audit somehow. It is
**not** the scaffolder's job to register it:

- Most people running `project-scaffold` have no audit host at all. Making the scaffolder
  depend on one means it either fails or nags in the common case.
- The scaffolder would have to know *where* the host repo is — configuration it doesn't
  have and shouldn't acquire.
- The audit is opt-in infrastructure; scaffolding a repo must not require it to exist.

**In discovery mode this is a non-problem** — the new repo appears in `gh repo list` and is
audited on the next run, automatically. Nothing to register, nothing to forget. This is the
strongest argument for discovery being the default.

**In explicit-list mode** the new repo must be added in two places, and *both* are easy to
miss:

1. `repos.txt` in the audit host
2. the audit token's repository access — otherwise the repo reports as an audit **error**
   rather than being audited (loud, at least, rather than silent)

`project-scaffold`'s final report carries a conditional one-liner pointing here. That's a
cross-reference, not ownership: the scaffolder mentions the step, this skill defines it.

## Reporting the resolved set

Whichever mode, print the count and mode with every run:

```
audited 12 repos (discovery, 2 ignored)
```

An audit whose coverage quietly shrinks is worse than no audit, because silence reads as
health. The count is what makes shrinkage visible — a drop from 12 to 4 is obvious in a way
that a missing repo never is.

Consider alerting if the resolved count drops sharply between runs; that usually means a
token permission changed, not that repos vanished.

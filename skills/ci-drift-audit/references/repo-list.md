# Which repos get audited

Where the audited set comes from, and where an adopter keeps it. The skill itself never
contains repo names — it's public, and repo lists are not.

## Conventional paths

In the **private host repo** that runs the audit:

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

**Token caveat.** Discovery is bounded by what the token can enumerate. A fine-grained PAT
scoped to "only select repositories" may not list them via the user endpoint — in which case
either grant "all repositories" (read-only Contents + Metadata is a modest risk for an
audit) or use explicit-list mode. Verify which behaviour you get before relying on it;
don't assume.

## Mode 2: explicit list

Read `repos.txt`, subtract `ignore.txt`. Use when:

- the audited set is deliberately narrow (a pilot, or a few flagship repos)
- it spans **multiple owners** or orgs, which a single `gh repo list <owner>` won't cover
- the token can't enumerate (see caveat above)
- you want the audited set reviewable in a PR

The cost is the maintenance burden above — so if you pick this mode, put a line in the
host repo's `CONTRIBUTING.md` telling people to add new repos here.

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

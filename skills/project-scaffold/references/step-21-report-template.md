# Step 21 — Final report template

Show the user a verbatim summary plus a "next steps" block. Use this template:

## Status block (fill in per-project)

- ✅ Local path
- ✅ GitHub URL (`gh repo view --web` to open in browser)
- ✅ Current branch (should be `develop`)
- ✅ Files + workflows created
- ✅ Branch protection status (applied / skipped with reason)
- ✅ Smoke test results
- 🔑 `RELEASE_PLEASE_TOKEN` secret status (`gh secret list` — set / ⚠️ still missing). If missing, repeat the Step 17 callout: add the repo to the PAT's access list, then `gh secret set RELEASE_PLEASE_TOKEN --repo <owner>/<name>`. The release workflows fail without it.

## "Next steps" block (copy verbatim)

```
Next steps:
1. (If flagged above) Add the RELEASE_PLEASE_TOKEN repo secret — release workflows fail without it
2. Push a feature branch and open a PR to develop to confirm CI runs green
3. Fill in the deploy target in `.github/workflows/deploy.yml`
4. Replace the smoke test stubs with real tests as you build features
5. When ready to release, merge develop → main; release-please will open a release PR
6. (Only if you run a CI drift audit) Discovery mode picks this repo up automatically on
   the next run. Explicit-list mode: add it to the audit host's
   `.github/ci-drift-audit/repos.txt` AND to the audit token's repository access

Useful commands (run from repo root):
- `npm run check:all` — run everything CI would run
- `npm run dev` — start dev servers
- `pre-commit run --all-files` — manually run all pre-commit hooks
```

(For Python-only projects: replace `npm run` with `python scripts/dev.py`.)

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
- 🚀 Deploy model: **tagged-only** — the deploy runs inside `release-please.yml` after a verified tag, and the host's branch auto-deploy is off. Two things must be done by hand before the first release actually ships: add the deploy-hook secret, and turn auto-deploy **off in the hosting dashboard** (the committed `autoDeploy: false` doesn't take effect on its own). See `gh-actions-init/references/tagged-deploy.md`.

## "Next steps" block (copy verbatim)

```
Next steps:
1. (If flagged above) Add the RELEASE_PLEASE_TOKEN repo secret — release workflows fail without it
2. Push a feature branch and open a PR to develop to confirm CI runs green
3. Wire the deploy: add the deploy-hook secret, and turn OFF branch auto-deploy in your
   hosting dashboard — deploys are driven by the tag, from the release workflow
4. Replace the smoke test stubs with real tests as you build features
5. When ready to release, merge develop → main — that's the only manual step; the release
   PR auto-merges, the tag is cut, and the tagged commit deploys
6. (Only if you run a CI drift audit) Discovery mode picks this repo up automatically on
   the next run. Explicit-list mode: add it to the audit host's
   `.github/ci-drift-audit/repos.txt` AND to the audit token's repository access

Useful commands (run from repo root):
- `npm run check:all` — run everything CI would run
- `npm run dev` — start dev servers
- `pre-commit run --all-files` — manually run all pre-commit hooks
```

(For Python-only projects: replace `npm run` with `python scripts/dev.py`.)

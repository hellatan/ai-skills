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
- 🚀 Deploy model: **tagged-only** — the deploy runs inside `release-please.yml` after a verified tag; nothing ships on a bare push to `main`. **This repo has no hosting service yet, so deploys are gated off** via the `RENDER_DEPLOY=false` repo variable (set in Step 17). Releases still tag and publish normally — only the deploy step is dormant, so the first release can't fail on a deploy hook that doesn't exist yet. Release-PR auto-merge is **on** (`RELEASE_AUTOMERGE` unset); set it to `false` any time you want to review a version bump by hand. See `gh-actions-init/references/tagged-deploy.md`.
- 🟢 Go-live checklist (only when you actually deploy this — in this order):
  1. Create the hosting service from the committed deploy config. It already carries `autoDeploy: false`, so a **fresh** service starts with auto-deploy off — there is nothing to flip. (An *existing* service is the opposite case: the file alone does nothing and you must turn auto-deploy off in the dashboard.)
  2. `gh secret set RENDER_DEPLOY_HOOK_URL --repo <owner>/<name>`
  3. `gh variable delete RENDER_DEPLOY --repo <owner>/<name>`
  4. The next release deploys the tagged commit automatically — no workflow edit needed. Deleting the variable before the secret exists leaves a window where a release would fail, so keep this order.

## "Next steps" block (copy verbatim)

```
Next steps:
1. (If flagged above) Add the RELEASE_PLEASE_TOKEN repo secret — release workflows fail without it
2. Push a feature branch and open a PR to develop to confirm CI runs green
3. Deploys are OFF until you have somewhere to deploy to (RENDER_DEPLOY=false) — nothing to
   do now. When you go live, follow the go-live checklist above; releases tag fine meanwhile
4. Replace the smoke test stubs with real tests as you build features
5. When ready to release, merge develop → main — that's the only manual step; the release
   PR auto-merges and the tag is cut (and, once deploys are on, the tagged commit ships)
6. (Only if you run a CI drift audit) Discovery mode picks this repo up automatically on
   the next run. Explicit-list mode: add it to the audit host's
   `.github/ci-drift-audit/repos.txt` AND to the audit token's repository access

Useful commands (run from repo root):
- `npm run check:all` — run everything CI would run
- `npm run dev` — start dev servers
- `pre-commit run --all-files` — manually run all pre-commit hooks
```

(For Python-only projects: replace `npm run` with `python scripts/dev.py`.)

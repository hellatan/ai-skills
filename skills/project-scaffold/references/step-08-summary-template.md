# Step 8 — Pre-execution summary template

Render the plan as a fenced code block with emoji-prefixed group headers (not a markdown bullet section). Monospace + emoji groups makes the summary scannable and visually distinct from surrounding chat.

Rules:

- Plain-English bullets, no jargon.
- Show only choices made for *this* user's project — don't list options they didn't pick.
- For omitted-but-decided items, add a parenthetical: `(skipping staging — you said no)`.
- The emoji headers and group structure are fixed; fill in specifics from user choices.
- **Emoji exception**: these emojis are user-requested for this single surface and override the global "no emojis unless asked" default. Keep everything else in the conversation emoji-free.

End the message with: *"Reply 'yes' / 'go' / 'looks good' to proceed, or tell me what to change."*

## Layout

````
📁 Project name:    <name>
📁 Where it'll live: <parent>/<name>
🔨 Stack:
   - <framework — plain-English, e.g. "Next.js (React + TypeScript) — handles both frontend and API routes">
   - <layout note, e.g. "Single-app layout (no separate backend service)">
🗄️ Database:                                   ← omit group entirely for research/library/static frontend (never asked)
   - <host + ORM, e.g. "Postgres on Neon, Drizzle ORM">
   (no database — you said no)                  ← show this line instead when DB was asked and declined
🔐 Auth:                                         ← include only when a database was chosen
   - <library, e.g. "Better Auth (email/password)">
   (no auth — you said no)                       ← show instead when DB chosen but auth declined
🌿 Branches:
   - `main` — release-only (release-please touches it)
   - `develop` — your day-to-day branch (default for PRs)
   (no staging — you said no, so no `stage` branch and no staging environment)
                                                 ← include only if user opted out; state it as a
                                                   settled choice, not a missing piece
   - `stage` — pre-production rehearsal, deploys from pre-release tags
                                                 ← include instead when staging was opted IN
🧹 Code quality (auto-runs on commit):
   - Pre-commit at repo root, single config
   - <linters/formatters per stack, e.g. "ESLint + Prettier for TS/TSX">
🤖 GitHub Actions (auto-runs on every PR):
   - checks (lint + typecheck + unit) · integration (if scoped) · e2e · build
   - Releases handled automatically by release-please
🔁 CI re-trigger:                               ← include only for gitflow repos (develop exists)
   - Comment `/rebuild` on a PR to re-run failed CI; `workflow_dispatch` for manual runs
🤖 PR review:
   - claude-code-review posts inline findings — on ready-for-review, not on drafts
🚀 Deploy:
   - Tagged-only — CI deploys the tagged commit; platform auto-deploy is OFF on every service
   - Production gated off until you have a service (RENDER_DEPLOY=false)
   (no staging environment — follows from the `stage` branch answer above)
                                                 ← include only if staging was declined
   - Staging: release-please-stage.yml cuts pre-release tags (v0.2.0-rc.N) off `stage`;
     staging deploy gated off until you have a service (RENDER_STAGE_DEPLOY=false)
                                                 ← include instead when staging was opted IN
📐 Docs:
   - docs/architecture.html — starter system map (fill-in SVG diagram + failure-modes table)
🐙 GitHub:
   - <Public|Private> repo under @<user>
   - Branch protection: <applied|skipped (reason, e.g. "free tier on private repo")>
````

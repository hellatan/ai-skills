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
   (skipping staging — you said no)              ← include only if user opted out
🧹 Code quality (auto-runs on commit):
   - Pre-commit at repo root, single config
   - <linters/formatters per stack, e.g. "ESLint + Prettier for TS/TSX">
🤖 GitHub Actions (auto-runs on every PR):
   - checks (lint + typecheck + unit) · integration (if scoped) · e2e · build
   - Releases handled automatically by release-please
🔁 CI re-trigger:                               ← include only for gitflow repos (develop exists)
   - Comment `/rebuild` on a PR to re-run failed CI; `workflow_dispatch` for manual runs
🚀 Deploy:
   - Stub workflow created — you'll fill in deploy target later
📐 Docs:
   - docs/architecture.html — starter system map (fill-in SVG diagram + failure-modes table)
🐙 GitHub:
   - <Public|Private> repo under @<user>
   - Branch protection: <applied|skipped (reason, e.g. "free tier on private repo")>
````

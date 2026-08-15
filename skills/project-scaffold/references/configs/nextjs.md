# Next.js Scaffold

Default frontend (and "fullstack-collapsed") choice. Use `create-next-app` for the actual scaffold so we don't have to maintain a hand-rolled boilerplate.

## Install

For a frontend-only project, scaffold at repo root:

```bash
npx create-next-app@latest . \
  --typescript \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --use-npm \
  --no-tailwind \
  --no-turbopack \
  --skip-git
```

| Flag | Why |
|---|---|
| `--typescript` | TypeScript out of the box |
| `--eslint` | ESLint configured |
| `--app` | App Router (the modern Next.js paradigm) |
| `--src-dir` | code lives in `src/` (cleaner separation) |
| `--import-alias "@/*"` | `@/components/Button` style imports |
| `--no-tailwind` | styling follows the Step 4 choice (CSS Modules default); omit only if the user picked Tailwind |
| `--no-turbopack` | skip Turbopack prompt; project can opt in later |
| `--skip-git` | Step 15 owns `git init` at repo root (avoids a nested `.git/`) |

For a fullstack project where the frontend is in a subdirectory:

```bash
npx create-next-app@latest frontend \
  --typescript \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --use-npm \
  --no-tailwind \
  --no-turbopack \
  --skip-git
```

## Post-scaffold cleanup (BEFORE other customizations)

`create-next-app` leaves behind files the skill needs to handle:

- **`AGENTS.md`** — Next 16+ ships this as a heads-up about breaking changes for AI tools. Keep it as-is, it's useful context for any LLM working on the project.
- **`CLAUDE.md`** — Next 16+ ships a stub. **Delete it** — the skill writes its own CLAUDE.md at repo root in Step 10. Keeping the Next stub creates two CLAUDE.md files (subdir vs root) that conflict.
- **`.git/`** — should not exist if `--skip-git` was passed. If it does (older create-next-app), remove it before the skill's `git init`:
  ```bash
  rm -rf .git AGENTS.md CLAUDE.md  # adjust based on which exist
  ```
- **`.gitignore`** — `create-next-app` writes a blanket `.env*` rule, which silently gitignores `.env.example` too. If the project will commit a `.env.example` (it should — documents required env vars), append the carve-out so it's tracked:
  ```bash
  grep -qxF '!.env.example' .gitignore || printf '\n# .env.example IS committed\n!.env.example\n' >> .gitignore
  ```
  (See `references/gitignores.md` — the Universal template already includes this negation; this step reconciles create-next-app's generated file.)

For the **subdir** install path, this cleanup happens in `frontend/`:
```bash
rm -rf frontend/.git frontend/CLAUDE.md
# Keep frontend/AGENTS.md — it's useful Next-specific context
```

## REQUIRED: pin `package.json` version to `0.1.0`

`create-next-app` writes `"version": "0.1.0"` to `package.json`, which is exactly the baseline release-please needs — so no change is needed, but pin it explicitly before the initial commit in case a future `create-next-app` default drifts:

```bash
# Idempotent pin (use Edit / sed / jq — any approach works):
node -e "const p=require('./package.json'); p.version='0.1.0'; require('fs').writeFileSync('./package.json', JSON.stringify(p,null,2)+'\n')"
```

**Why `0.1.0` and not `0.0.0`:** the manifest invariant requires `package.json` == `.release-please-manifest.json` at scaffold time, seeded at a normal pre-1.0 version — an exact-`0.0.0` manifest bootstraps the first release straight to `1.0.0` regardless of commit type. Canonical explanation + issue link: `gh-actions-init/references/release-please.md`, "Manifest — match current version".

Step 15 verifies this invariant before the initial commit and aborts if it's wrong, so a missed pin surfaces immediately rather than after the first release attempt.

## Post-scaffold customizations

After `create-next-app` runs, the skill should:

1. **Install additional dev deps** that match the rest of the toolchain:

```bash
npm install --save-dev \
  prettier \
  @ianvs/prettier-plugin-sort-imports
```

Test runners (Vitest, Playwright, Testing Library) are **not** installed here — `/testing-init` owns them and Step 14 runs it. See `testing-init/references/runners.md`.

**Do NOT install** `@eslint/js`, `typescript-eslint`, or `eslint-config-prettier` — they conflict with `eslint-config-next`'s pinned versions and produce ERESOLVE errors. Next's flat config already provides everything they'd add (except `@typescript-eslint/consistent-type-imports`, which works fine when extending Next's config without those packages).

2. **Extend the default `eslint.config.mjs`** that `create-next-app` generates rather than replacing it. Add the `@typescript-eslint/consistent-type-imports` rule via Next's config:

```js
// eslint.config.mjs (extending what create-next-app generated)
import { FlatCompat } from '@eslint/eslintrc';

const compat = new FlatCompat({ baseDirectory: import.meta.dirname });

const eslintConfig = [
  ...compat.extends('next/core-web-vitals', 'next/typescript'),
  {
    rules: {
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      // Require braces on every control statement, even single-line bodies.
      // ESLint inserts the braces (autofixable); Prettier then formats the block.
      curly: ['error', 'all'],
    },
  },
  {
    ignores: ['.next/', 'out/', 'dist/', 'node_modules/', 'coverage/'],
  },
];

export default eslintConfig;
```

3. **Write `.prettierrc`** with the type-imports-first sort plugin (see `node-ts.md`).

4. **Run `npx prettier --write .` once after writing `.prettierrc`** to reformat `eslint.config.mjs` and any other files `create-next-app` left in non-prettier style. Otherwise CI's `format:check` will fail on first push, and the skill's smoke test in Step 20 would only catch it after several minutes of confusion.

5. **Add scripts** for the canonical commands:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "next typegen && tsc --noEmit",
    "test": "vitest run",
    "test:unit": "vitest run --dir src",
    "test:integration": "vitest run --dir tests/integration",
    "test:e2e": "playwright test",
    "check:all": "npm run lint && npm run format:check && npm run typecheck && npm run test"
  }
}
```

**Note on `"lint"`:** Use `eslint`, not `next lint`. The `next lint` command was deprecated in Next.js 15 and **removed in Next.js 16** (the version `create-next-app` installs by default now). The ESLint flat config that Next.js scaffolds (`eslint.config.mjs`) already extends `next/core-web-vitals` + `next/typescript`, so running `eslint` directly applies all the same rules with no functional loss. `create-next-app` itself generates `"lint": "eslint"` in its scripts as of Next 16 — overriding with `"next lint"` would re-introduce a broken script.

**Note on `"typecheck"`:** Prefix `tsc --noEmit` with `next typegen`. On Next.js 16 the code `create-next-app` generates references globally-declared route types — `src/app/layout.tsx` uses `LayoutProps`, pages use `PageProps` — that don't exist in the type graph until Next writes them into `.next/types`. `next typegen` generates exactly those declarations without a full build (seconds, not a compile). Bare `tsc --noEmit` on a checkout with no `.next/` fails with:

```
src/app/layout.tsx(22,50): error TS2304: Cannot find name 'LayoutProps'.
```

This is a CI-only failure with a local false negative, so **the Step 20 smoke test cannot catch it**: `create-next-app` runs typegen while scaffolding and leaves `.next/` on disk, so `npm run typecheck` passes on the scaffolding machine and fails on CI's first clean checkout. Reproduce the CI condition with `rm -rf .next && npx tsc --noEmit`; `rm -rf .next && npx next typegen && npx tsc --noEmit` passes. (Confirmed on Next 16.3.1.)

Non-Next TypeScript projects keep the bare `"typecheck": "tsc --noEmit"` — see `nodejs-backend.md`. This is a Next-specific requirement, not a general one.

6. **Test stubs + runner configs are owned by `/testing-init`** (Step 14 runs its execution phase): smoke stubs, `vitest.config.ts` — including the required `**/e2e/**` exclude, without which `npm run test` crashes on Playwright specs — and `playwright.config.ts`. See `testing-init/references/test-stubs.md` and `testing-init/references/runners.md`.

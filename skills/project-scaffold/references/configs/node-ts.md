# Node / TypeScript Generic Configs

Shared reference for Next.js and Fastify scaffolds. The framework-specific files (`nextjs.md`, `nodejs-backend.md`) will reference parts of this when building the actual config.

---

## `.prettierrc` — type-imports-first

Includes `@ianvs/prettier-plugin-sort-imports` to enforce **type imports first, value imports second**, both alphabetized within their group.

```json
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "always",
  "endOfLine": "lf",
  "plugins": ["@ianvs/prettier-plugin-sort-imports"],
  "importOrder": [
    "<TYPES>^(node:)",
    "<TYPES>",
    "<TYPES>^[.]",
    "",
    "<BUILTIN_MODULES>",
    "<THIRD_PARTY_MODULES>",
    "",
    "^@/(.*)$",
    "",
    "^[./]"
  ],
  "importOrderTypeScriptVersion": "5.0.0"
}
```

Required dev dep:
```bash
npm install --save-dev @ianvs/prettier-plugin-sort-imports
```

### What this produces

```ts
// Type imports — grouped first, sorted within their group
import type { Server } from 'node:http';
import type { FC, ReactNode } from 'react';
import type { User } from '@/types/user';
import type { Props } from './types';

// Value imports — second
import { readFile } from 'node:fs/promises';
import { useEffect, useState } from 'react';
import { Button } from '@/components/Button';
import { formatDate } from './utils';
```

### Why prettier and not eslint

`eslint-plugin-import`'s `import/order` rule can also sort, but it fights with prettier on whitespace and doesn't cleanly separate type vs value imports. Doing it in prettier means the sort is deterministic, runs as part of `format`, and pre-commit catches it on every commit. ESLint still owns `@typescript-eslint/consistent-type-imports` (forces `import type` when imports are type-only) — the two work together.

---

## `.prettierignore`

```
node_modules/
dist/
build/
.next/
out/
coverage/
*.lock
package-lock.json
CHANGELOG.md

# Prettier's YAML formatting mangles hand-maintained GitHub Actions workflow
# files (reflowing inline comments) for zero benefit — skip all YAML.
*.yml
*.yaml
```

`CHANGELOG.md` is ignored because release-please owns its formatting — the changelog it generates doesn't satisfy prettier's `--check`, so without this line the first release turns CI's `format:check` red on `main` the moment it lands.

`*.yml` / `*.yaml` are ignored because prettier's YAML formatting is finicky and mangles GitHub Actions workflow files (reflowing inline comments into wrapped messes) for zero benefit — workflow files are small, hand-maintained, and benefit from intentional formatting.

---

## `eslint.config.js` — flat config (ESLint 9+)

```js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import prettier from 'eslint-config-prettier';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  prettier,
  {
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/consistent-type-imports': 'error',
      // Require braces on every control statement, even single-line bodies.
      // ESLint inserts the braces (autofixable); Prettier then formats the block.
      curly: ['error', 'all'],
    },
  },
  {
    ignores: ['dist/', 'build/', '.next/', 'out/', 'node_modules/', 'coverage/'],
  },
);
```

Required dev deps:
```bash
npm install --save-dev eslint @eslint/js typescript-eslint eslint-config-prettier
```

### The `curly: ['error', 'all']` rule

`curly` requires braces on every control statement, even single-line bodies (`if (x) return;` → `if (x) {\n  return;\n}`). It's autofixable: ESLint inserts the braces, then Prettier formats the block across its own lines. This is an ESLint rule, **not** Prettier — Prettier has no option to add braces. A freshly scaffolded repo has no pre-existing code, so the autofix never has anything to rewrite; the rule just keeps new code consistent from commit one.

### Retrofitting `curly` to an existing repo

When you add `curly` to a codebase that already has brace-less control statements and run `eslint --fix`, the autofix adds braces and pushes the statement onto its own line. **This can silently delete `eslint-disable-next-line` directives.** If a directive sat directly above a brace-less `if (x) stmt;`, after the fix it lands on the new `if (x) {` line — which has no error — so with `reportUnusedDisableDirectives` on (the default in many configs) it's flagged as unused and `--fix` removes it, re-exposing the suppressed error. Relocate the directive **inside** the new braces, directly above the statement:

```ts
if (local) {
  // eslint-disable-next-line react-hooks/set-state-in-effect
  setState(local);
}
```

After running the curly autofix on an existing repo, re-check that no `eslint-disable-next-line` directives were stranded above a now-braced `if` (and possibly auto-removed) before committing.

### Important: ESLint config-at-cwd (monorepo gotcha)

ESLint 9's flat config looks for `eslint.config.js` (or `.mjs`/`.ts`) **in the current working directory** — not in any parent.

For **fullstack repos with frontend in subdir**, this means:

- `frontend/eslint.config.js` works fine when running `eslint` from `frontend/`
- It does NOT work when pre-commit runs eslint from repo root
- The pre-commit hook must `cd frontend && npx eslint <files>` (handled in `precommit-unified.md`)

If you ever see "no config found" errors, double-check where eslint was invoked from.

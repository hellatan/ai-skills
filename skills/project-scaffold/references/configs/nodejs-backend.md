# Node.js Backend (Fastify)

Use this only when the user explicitly opted for a separate Node backend instead of the Next.js-only fullstack default (which handles backend via API routes).

## Install

```bash
npm init -y
npm install fastify
npm install --save-dev \
  typescript \
  tsx \
  @types/node \
  vitest \
  @ianvs/prettier-plugin-sort-imports \
  prettier \
  eslint \
  @eslint/js \
  typescript-eslint \
  eslint-config-prettier
```

## `package.json` scripts

```json
{
  "name": "<project-name>",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:unit": "vitest run --dir src",
    "test:integration": "vitest run --dir tests/integration",
    "check:all": "npm run lint && npm run format:check && npm run typecheck && npm run test"
  }
}
```

## `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src", "tests"],
  "exclude": ["node_modules", "dist"]
}
```

## `eslint.config.js`

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
    ignores: ['dist/', 'build/', 'node_modules/', 'coverage/'],
  },
);
```

## `.prettierrc`

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

This produces type imports first (alphabetized), then a blank line, then value imports (alphabetized within their groups: built-ins → third-party → `@/*` aliases → relative). See `node-ts.md` for the full output example.

## `.prettierignore`

```
node_modules/
dist/
build/
coverage/
*.lock
package-lock.json

# release-please rewrites both of these in its own style on every release PR — keep prettier off them.
CHANGELOG.md
.github/.release-please-manifest.json

# Prettier's YAML formatting mangles hand-maintained GitHub Actions workflow
# files (reflowing inline comments) for zero benefit — skip all YAML.
*.yml
*.yaml
```

The release-please carve-outs and the YAML rationale are the same as the shared config — see `node-ts.md`, "`.prettierignore`".

## Stub source file

`src/index.ts`:
```typescript
import Fastify from 'fastify';

const app = Fastify({ logger: true });

app.get('/', async () => ({ status: 'ok' }));

const start = async () => {
  try {
    await app.listen({ port: 3000, host: '0.0.0.0' });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
```

## Stub test

`src/__tests__/smoke.test.ts`:
```typescript
import { describe, it, expect } from 'vitest';

describe('smoke', () => {
  it('passes', () => {
    expect(1).toBe(1);
  });
});
```

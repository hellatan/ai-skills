# Styling convention — CSS Modules (default)

Written into the new project's canonical `AGENTS.md` `## Conventions` when the user picks **CSS Modules** at Step 4. CSS Modules is the scaffold's default styling approach.

## What to scaffold

- Pass `--no-tailwind` to `create-next-app`. Do **not** install shadcn/ui.
- Co-locate a `*.module.css` next to each component (`Foo.tsx` → `Foo.module.css`).
- `create-next-app --no-tailwind` already ships `src/app/page.module.css` + global `src/app/globals.css` — keep that pattern as the reference shape.

## Convention text (drop into AGENTS.md `## Conventions`)

> **Styling: CSS Modules.** Each component gets a co-located `*.module.css` file; import it as `styles` and reference `className={styles.foo}`. No inline `style={{...}}` for anything beyond truly dynamic values (computed positions, etc.). No Tailwind utility classes. Define design tokens as CSS custom properties scoped to a component-root class (mirror `src/app/page.module.css`); put genuinely global tokens/resets in `src/app/globals.css`.

## Why CSS Modules is the default

- Scoped by default — no global class collisions, no naming-convention discipline (BEM etc.) needed.
- Zero extra dependencies — it's built into Next.js.
- Plain CSS knowledge transfers directly; nothing framework-specific to learn.

## Other choices (Step 4 offers these too)

- **Vanilla Extract** — type-safe, zero-runtime CSS-in-TS. Styles live in `*.css.ts` files compiled at build time; you get TypeScript types on class names and tokens. Same `--no-tailwind`, no shadcn. Setup:
  - `npm i -D @vanilla-extract/css @vanilla-extract/next-plugin`
  - Wrap the Next config: in `next.config.ts`, `import { createVanillaExtractPlugin } from '@vanilla-extract/next-plugin'` and `export default createVanillaExtractPlugin()(nextConfig)`.
  - Co-locate `Foo.css.ts` next to `Foo.tsx`; `export const foo = style({...})` and use `className={foo}`. Define tokens with `createTheme`/`createGlobalTheme` instead of CSS custom properties.
- **Tailwind** — utility-first. Available for users who prefer it; omit `--no-tailwind`. Never the scaffold's default or recommended pick.
- **Tailwind + shadcn/ui** — Tailwind plus prebuilt components; run shadcn init after `create-next-app`.

(There's no "plain CSS" option — `create-next-app` always runs a build, so a single unscoped global stylesheet is strictly worse than CSS Modules for the same effort. Genuinely global tokens/resets still go in `src/app/globals.css` regardless of the choice above.)

When the user picks a non-CSS-Modules option, generate that stack's idiomatic setup instead and skip the CSS-Modules convention text above.

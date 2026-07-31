# Plain-English Concept Explainers

When the skill mentions any of these concepts during scaffold, surface the matching explainer. Use them inline at the moment they're relevant — not as a wall of text upfront.

## Branch protection

> "Branch protection" means GitHub physically blocks you (and anyone else) from pushing broken code straight to important branches like `main` or `develop`. Even if you forget the rules, GitHub catches it. Without protection, the only thing stopping a bad commit is your own discipline.

## Pre-commit hooks

> "Pre-commit hooks" run automatic checks every time you save a commit — they catch lint errors, formatting mistakes, and type errors *before* the bad code ever leaves your machine. Saves you from pushing something that'd fail the CI check anyway.

## CI (continuous integration)

> "CI" is shorthand for "the robot that runs every check on every Pull Request." When you open a PR, GitHub spins up a fresh machine, installs your project, and runs the lint / test / build steps. If any fail, the PR can't be merged.

## Conventional commits

> Your commit messages need to start with one of these prefixes:
>
> - `feat:` — a new feature users will see
> - `fix:` — a bug fix
> - `chore:` — internal cleanup with no user-visible change (dependency bumps, config tweaks)
> - `docs:` — documentation changes only
> - `refactor:` — restructuring code without changing behavior
> - `test:` — adding or fixing tests
>
> Example: `feat: add dark mode toggle` or `fix: prevent crash when user logs out`.
>
> This is how release-please decides whether your next release is a big version bump or a small one.

## Release-please

> Going with **release-please** to handle releases — it watches your commits, opens a Pull Request when you have changes worth shipping, and handles the version bump + changelog for you automatically. Reply "ok" or specify if you have a different release tool in mind.

## Semver / version bumps

> Versions follow `MAJOR.MINOR.PATCH` (e.g. `1.4.2`):
>
> - **MAJOR** — bump when you make a breaking change (existing users have to update their code to keep working)
> - **MINOR** — bump when you add a feature (existing users can ignore it and nothing breaks)
> - **PATCH** — bump when you fix a bug (no new features, just fixes)

## Staging environment / branch

> A staging branch is like a dress rehearsal — code goes there first, deploys to a separate copy of your site only you can see, and you click around to make sure nothing's broken before it goes live to real users. If you're solo or just starting out, you can skip this and add it later.

## Public vs private repo

> - **Public** — anyone on the internet can see the code (still need permission to *change* it). Free GitHub plan includes branch protection.
> - **Private** — only people you invite can see it. Branch protection requires GitHub Pro (~$4/mo) or making the repo public.

## Monorepo

> A "monorepo" means putting multiple related projects in one repository instead of splitting them into separate repos. For fullstack, this means your frontend code and backend code share one Git history.

## `pyproject.toml` / `package.json`

> Two key config files for your project — `pyproject.toml` (Python) and/or `package.json` (Node.js). These are like a recipe card for your project: they list which dependencies it needs, which versions of Python or Node to use, and which commands run things.

## `gh` CLI

> "gh" is GitHub's command-line tool — it lets the skill create your repo, set permissions, and apply branch protection from the terminal instead of you clicking around the GitHub website. If it's not installed, the skill will tell you how to install it (or you can skip GitHub creation and just keep the project local).

## Consolidated CI pipeline

> Every PR runs through a handful of automatic checks before it can merge. The fast ones
> are consolidated into a single `checks` job so they share one checkout + install:
>
> 1. **checks** — lint + type-check + unit tests in one job (does the code follow style
>    rules, have valid types, and pass the small individual tests?)
> 2. **integration tests** — do the pieces work together? (its own job; only if you scoped integration in)
> 3. **e2e tests** — does the whole app work from a real user's perspective? (its own job — it needs a browser)
> 4. **production build** — does the code actually compile into shippable output?
>
> The common Next.js setup lands as **three jobs — `checks`, `e2e`, `build`** (integration
> adds a fourth when scoped in). All must be green for the PR to merge into a protected branch.

## The bootstrap exception (push-only, scoped)

> Normal rule: never push directly to `main`, `develop`, or `stage`. Always go through a Pull Request.
>
> Exception: when first creating the GitHub repo from this scaffold, those branches don't exist on the remote yet. There's a one-time push to seed them. After that, the rule kicks back in — no more direct pushes, no exception for merges.

# Changelog

## [1.12.0](https://github.com/hellatan/claude-skills/compare/v1.11.0...v1.12.0) (2026-07-31)


### Features

* **gh-actions-init:** document what belongs in the checks job vs its own job ([#117](https://github.com/hellatan/claude-skills/issues/117)) ([ff75586](https://github.com/hellatan/claude-skills/commit/ff755866254e45f4995f2e00ce9447fabcfb0595))
* **precommit-init:** stop prettier-formatting YAML in the hook file filter ([#116](https://github.com/hellatan/claude-skills/issues/116)) ([a83ce5e](https://github.com/hellatan/claude-skills/commit/a83ce5e35d0ed9073ff14e0fb34d614f9a3e9cda))

## [1.11.0](https://github.com/hellatan/claude-skills/compare/v1.10.1...v1.11.0) (2026-07-31)


### Features

* **project-scaffold:** exclude YAML from the scaffolded .prettierignore ([#111](https://github.com/hellatan/claude-skills/issues/111)) ([43545ae](https://github.com/hellatan/claude-skills/commit/43545ae772c691082ec7e171c61700e714e93cdb))

## [1.10.1](https://github.com/hellatan/claude-skills/compare/v1.10.0...v1.10.1) (2026-07-31)


### Bug Fixes

* **gh-actions-init:** stagger the release-health cron off the congested :00 slot ([#109](https://github.com/hellatan/claude-skills/issues/109)) ([c0fa344](https://github.com/hellatan/claude-skills/commit/c0fa344a4013abbdef847cebce219d4ef494ea0a))

## [1.10.0](https://github.com/hellatan/claude-skills/compare/v1.9.0...v1.10.0) (2026-07-30)


### Features

* **gh-actions-init:** scaffold the main → develop back-merge workflow ([#105](https://github.com/hellatan/claude-skills/issues/105)) ([a76f80c](https://github.com/hellatan/claude-skills/commit/a76f80c080cd0d7beb27774438ac93659c917385))

## [1.9.0](https://github.com/hellatan/claude-skills/compare/v1.8.1...v1.9.0) (2026-07-30)


### Features

* **gh-actions-init:** make the alert channel a scaffold-time choice ([#98](https://github.com/hellatan/claude-skills/issues/98)) ([df9d8f2](https://github.com/hellatan/claude-skills/commit/df9d8f2d1630a785e60053f7baa19962019fa5c1))

## [1.8.1](https://github.com/hellatan/claude-skills/compare/v1.8.0...v1.8.1) (2026-07-28)


### Bug Fixes

* **gh-actions-init:** verify release tags via tag refs, not unprefixed outputs ([#94](https://github.com/hellatan/claude-skills/issues/94)) ([b8c631e](https://github.com/hellatan/claude-skills/commit/b8c631e57b5d895bf2660f7970efec49feec94aa))

## [1.8.0](https://github.com/hellatan/claude-skills/compare/v1.7.0...v1.8.0) (2026-07-25)


### Features

* **gh-actions-init:** scaffold release verification + failure alerting ([#89](https://github.com/hellatan/claude-skills/issues/89)) ([801b132](https://github.com/hellatan/claude-skills/commit/801b1323bc694556e48af09bcf2c68966c578fa8))


### Bug Fixes

* **ci-drift-audit:** detect workflows by behaviour, not filename ([#88](https://github.com/hellatan/claude-skills/issues/88)) ([5d67588](https://github.com/hellatan/claude-skills/commit/5d675887e0cadfb3b74fe9373ece47c523b4c141))

## [1.7.0](https://github.com/hellatan/claude-skills/compare/v1.6.0...v1.7.0) (2026-07-25)


### Features

* **ci-drift-audit:** check the develop → main promotion workflow ([#85](https://github.com/hellatan/claude-skills/issues/85)) ([0c1b436](https://github.com/hellatan/claude-skills/commit/0c1b436518357d0c48296acf85aa855522da67e8))

## [1.6.0](https://github.com/hellatan/claude-skills/compare/v1.5.1...v1.6.0) (2026-07-25)


### Features

* **ci-drift-audit:** add skill defining the CI baseline drift checks ([#71](https://github.com/hellatan/claude-skills/issues/71)) ([0973a9c](https://github.com/hellatan/claude-skills/commit/0973a9c62f5aa37860207da0d3f909c998a828ec))
* **claude-md-init:** add living-doc note to every template ([#72](https://github.com/hellatan/claude-skills/issues/72)) ([3805d57](https://github.com/hellatan/claude-skills/commit/3805d570e66e6362ea844896e20ae2d31835edf7))
* **claude-md-init:** add toolbox/scripts-repo template for manifest-less repos ([#70](https://github.com/hellatan/claude-skills/issues/70)) ([785e852](https://github.com/hellatan/claude-skills/commit/785e852b0ad49ce369ee00756123f53f1265bbce))
* **gh-actions-init:** bake the cost-verification procedure into the skill ([#74](https://github.com/hellatan/claude-skills/issues/74)) ([97706b4](https://github.com/hellatan/claude-skills/commit/97706b489ed81bb2f847759d8d847961033e52c4))
* **gh-actions-init:** match /rebuild as a prefix command, not exact body ([#68](https://github.com/hellatan/claude-skills/issues/68)) ([0cae3f5](https://github.com/hellatan/claude-skills/commit/0cae3f58eeb33500f63a2580b446d6cb7b231031))
* **gitflow-init:** scaffold CONTRIBUTING.md as step 8 ([#73](https://github.com/hellatan/claude-skills/issues/73)) ([bfb1f5c](https://github.com/hellatan/claude-skills/commit/bfb1f5c2b3006ffc8191cefc6a85db6d145f0842))
* **testing-init:** cache Playwright browsers in the e2e CI job ([#67](https://github.com/hellatan/claude-skills/issues/67)) ([6d0c129](https://github.com/hellatan/claude-skills/commit/6d0c1299634fc1f6f7852f0ac0c2a57be2b9847d))

## [1.5.1](https://github.com/hellatan/claude-skills/compare/v1.5.0...v1.5.1) (2026-07-20)


### Bug Fixes

* **gh-actions-init,testing-init:** drop duplicate push-on-develop CI trigger ([#63](https://github.com/hellatan/claude-skills/issues/63)) ([8243149](https://github.com/hellatan/claude-skills/commit/8243149f8cca66d2ecdd27865493fece3ccccb80))
* **gitflow-init:** probe protection endpoint instead of plan.name for tier detection ([#61](https://github.com/hellatan/claude-skills/issues/61)) ([e13cc20](https://github.com/hellatan/claude-skills/commit/e13cc2055e22fb6706955ce7c058fceb1638f211))

## [1.5.0](https://github.com/hellatan/claude-skills/compare/v1.4.0...v1.5.0) (2026-07-06)


### Features

* **project-scaffold:** scaffold docs/architecture.html living system map ([#54](https://github.com/hellatan/claude-skills/issues/54)) ([c24618c](https://github.com/hellatan/claude-skills/commit/c24618cd4bd58d290d67ceb163cd70729fd9bead))

## [1.4.0](https://github.com/hellatan/claude-skills/compare/v1.3.0...v1.4.0) (2026-06-14)


### Features

* **project-scaffold:** bake always-braces ESLint rule into config references ([#52](https://github.com/hellatan/claude-skills/issues/52)) ([dd38e10](https://github.com/hellatan/claude-skills/commit/dd38e10b2bbdc7849b63f7d6e6396f3d739069a4))

## [1.3.0](https://github.com/hellatan/claude-skills/compare/v1.2.0...v1.3.0) (2026-06-12)


### Features

* **gh-actions-init:** author bot PRs with RELEASE_PLEASE_TOKEN PAT by default ([#46](https://github.com/hellatan/claude-skills/issues/46)) ([48b94cc](https://github.com/hellatan/claude-skills/commit/48b94cc3e46eec5e644df4a88b063130a8600939))
* **release-workflow-init:** add framework-less git/release orchestrator skill ([f4212d0](https://github.com/hellatan/claude-skills/commit/f4212d0ad35621fe0be8d653657bd98dfebbb1cd))


### Bug Fixes

* **gh-actions-init:** pin release-please target-branch to main ([#44](https://github.com/hellatan/claude-skills/issues/44)) ([4dc01e9](https://github.com/hellatan/claude-skills/commit/4dc01e9f038a7d72759aba30d8f08c82fa984310))

## [1.2.0](https://github.com/hellatan/claude-skills/compare/v1.1.0...v1.2.0) (2026-06-01)


### Features

* **gh-actions-init:** CI re-trigger ergonomics (/rebuild + workflow_dispatch + PAT notes) ([#41](https://github.com/hellatan/claude-skills/issues/41)) ([c75bdb0](https://github.com/hellatan/claude-skills/commit/c75bdb0f89633092a3aa045a8fce24205a93f435))

## [1.1.0](https://github.com/hellatan/claude-skills/compare/v1.0.0...v1.1.0) (2026-05-31)


### Features

* **project-scaffold:** document toolchain non-goals (no Make, no Biome) ([#38](https://github.com/hellatan/claude-skills/issues/38)) ([662cc4f](https://github.com/hellatan/claude-skills/commit/662cc4fa2ae57eb955a91a9e9b5e8081c09b03c0))

## 1.0.0 (2026-05-31)


### Features

* **claude-md-init:** new skill for adding CLAUDE.md to existing repos ([#12](https://github.com/hellatan/claude-skills/issues/12)) ([b2d949f](https://github.com/hellatan/claude-skills/commit/b2d949f8163588edee0b6c02655de581ee1ab65f))
* **gh-actions-init:** add develop→main auto-PR workflow template ([#25](https://github.com/hellatan/claude-skills/issues/25)) ([6ac9834](https://github.com/hellatan/claude-skills/commit/6ac983402850844edef949096f689c2ee9f491c3))
* **gh-actions-init:** new skill for adding GitHub Actions to existing repos ([#4](https://github.com/hellatan/claude-skills/issues/4)) ([9b2c2ee](https://github.com/hellatan/claude-skills/commit/9b2c2eefaa9f3c22f79ff27caf2612b954fbbb46))
* **gitflow-init:** new skill for setting up gitflow on existing repos ([#10](https://github.com/hellatan/claude-skills/issues/10)) ([917579d](https://github.com/hellatan/claude-skills/commit/917579d56b3fa10d70145b7d32d107bf36456f72))
* package repo as the 'ht-skills' Claude Code plugin ([#19](https://github.com/hellatan/claude-skills/issues/19)) ([32cc398](https://github.com/hellatan/claude-skills/commit/32cc398ecf2c5149edf6f41f48dfe26a38c16a32))
* **precommit-init:** new skill for adding pre-commit to existing repos ([#11](https://github.com/hellatan/claude-skills/issues/11)) ([8a82db0](https://github.com/hellatan/claude-skills/commit/8a82db0795754652cb5a6cf9882634176748a16c))
* **project-scaffold:** add opt-in database (Drizzle) and auth (Better Auth) steps ([#28](https://github.com/hellatan/claude-skills/issues/28)) ([9e790dd](https://github.com/hellatan/claude-skills/commit/9e790dddebb01fcb8f44745096e900bdb92ea315))
* **project-scaffold:** emoji-grouped Step 7 summary ([#1](https://github.com/hellatan/claude-skills/issues/1)) ([47abc39](https://github.com/hellatan/claude-skills/commit/47abc393c1208d097c19a60dfe73ec9066ff5ebd))
* **project-scaffold:** scaffold per-repo git-workflow rule into new projects ([#15](https://github.com/hellatan/claude-skills/issues/15)) ([fe63539](https://github.com/hellatan/claude-skills/commit/fe635392362f11b332ef8c9004cc05f320a58bf7))
* **project-scaffold:** styling choice (CSS Modules default), opt-in Render Blueprint, track .env.example ([#26](https://github.com/hellatan/claude-skills/issues/26)) ([81b290d](https://github.com/hellatan/claude-skills/commit/81b290d56a6d29c981c9fbc0ca1092a751815163))
* scaffold commit-hygiene, env-lazy, and worktree convention rules ([#27](https://github.com/hellatan/claude-skills/issues/27)) ([900dc9c](https://github.com/hellatan/claude-skills/commit/900dc9cc317ef510d686af120fb7e25e2a0b0c85))
* **testing-init:** new skill for adding tests to existing repos ([#3](https://github.com/hellatan/claude-skills/issues/3)) ([64e330b](https://github.com/hellatan/claude-skills/commit/64e330bb6940b7b103a384a47470e8c0c5a7574b))


### Bug Fixes

* bump claude-skills repo's own workflows to Node 24-supporting majors ([#20](https://github.com/hellatan/claude-skills/issues/20)) ([ce61eca](https://github.com/hellatan/claude-skills/commit/ce61eca156898cf391a182b1375e0cdab52b7276))
* bump GitHub Actions to Node 24-supporting majors ([#6](https://github.com/hellatan/claude-skills/issues/6)) ([c2fb246](https://github.com/hellatan/claude-skills/commit/c2fb246c222f84876954425e8e0d42fd4b4f6fe4))
* **gh-actions-init:** correct fullstack-monorepo release-please config so first release auto-tags ([#24](https://github.com/hellatan/claude-skills/issues/24)) ([e454e79](https://github.com/hellatan/claude-skills/commit/e454e7962f367eccb537e271ce79503e268db2a6))
* **gitflow-init:** derive branch-protection contexts from ci.yml ([#16](https://github.com/hellatan/claude-skills/issues/16)) ([01f0280](https://github.com/hellatan/claude-skills/commit/01f0280d1418d1bff9d8be576cb2123e2d255124))
* **project-scaffold:** apply pre-commit auto-fixers before initial commit ([#14](https://github.com/hellatan/claude-skills/issues/14)) ([92e5c9d](https://github.com/hellatan/claude-skills/commit/92e5c9d3e1fa680ee5863c505ad9e774ead5847c))
* **project-scaffold:** avoid release-please 1.0.0 bootstrap on first release ([#22](https://github.com/hellatan/claude-skills/issues/22)) ([a5bc3a8](https://github.com/hellatan/claude-skills/commit/a5bc3a82a9351899b66aa9385e769e67cf5d5451))
* **project-scaffold:** correct release-please config so first release auto-tags ([#23](https://github.com/hellatan/claude-skills/issues/23)) ([9a3ad4f](https://github.com/hellatan/claude-skills/commit/9a3ad4f00dd9dd84660e0cc5f859f52d2338b509))
* **project-scaffold:** enable GitHub Actions to create PRs on freshly scaffolded repos ([#21](https://github.com/hellatan/claude-skills/issues/21)) ([c5fa58f](https://github.com/hellatan/claude-skills/commit/c5fa58f7c11f7f7c02e5d43ee39919645f368f69))
* **project-scaffold:** ignore .claude/worktrees/ in scaffolded repos and this repo ([#29](https://github.com/hellatan/claude-skills/issues/29)) ([06e7ac7](https://github.com/hellatan/claude-skills/commit/06e7ac70817db7fafd1bb208d10b6591614941b2))
* **project-scaffold:** replace deprecated 'next lint' with 'eslint' ([#17](https://github.com/hellatan/claude-skills/issues/17)) ([27d190b](https://github.com/hellatan/claude-skills/commit/27d190ba5cfc453ca2d121520754dc53571d3a3a))

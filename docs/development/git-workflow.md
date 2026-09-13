# Git workflow

These rules apply to human and agent contributors.

1. Branch from `develop` and target pull requests at `develop`.
2. Inspect `git status` and `git diff --stat origin/develop...HEAD` before
   opening a pull request. Preserve unrelated work.
3. Use conventional commits with a meaningful body that states rationale,
   scope, and validation when the change is not self-evident.
4. Use an explicit source and destination refspec for every first push:

   ```bash
   git push -u origin <local-branch>:<remote-branch>
   ```

   A bare `git push -u origin <local-branch>` can behave differently under
   different `push.default` configurations. Do not assume it creates a remote
   feature branch.
5. Do not push, change repository protection, create a remote repository, or
   deploy without the user's current authorization. A local inspection cannot
   prove that hosted or managed policy is absent.
6. Promotion and release procedures are repository automation. Follow their
   documented gates and observed harness approval behavior; do not disable
   security controls to work around a refusal.


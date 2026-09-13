# Step 16 — Inspect push constraints before pushing

The bootstrap in Step 17 creates a remote and seeds its initial branches. Inspect
the local Git configuration before that action so a known constraint does not
surprise the user mid-run. This inspection is informative: it cannot prove that
no harness, host, or organization policy will intervene.

## Inspect

```bash
# Git's configured global hook directory, if any.
git config --global core.hooksPath || true

# A shell wrapper can change what a Git invocation does.
type git || true

# A template directory can seed hooks into freshly initialized repositories.
git config --global init.templateDir || true
```

If a configured hook directory is present, inspect its `pre-push` file without
modifying it. Do not scan personal agent directories as a substitute for the
active harness's policy, and do not infer that an empty result means protection
is absent.

## Report and gate

Before Step 17, report the sources inspected, any observed constraint, and the
remaining unknowns. Use the active agent harness's actual approval mechanism
for the remote creation and push. Do not disable hooks, invent an override
environment variable, or treat a local scan as authorization.

If a constraint prevents the action, leave the local scaffold intact and give
the user the observed reason and the exact next action they can take.

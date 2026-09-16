# Handoff: <project — topic>

- **Date:** <YYYY-MM-DD (HH:MM tz)>
- **Project:** <repo / project, and the checkout or worktree path>
- **Status:** <not started | in progress, blocked on X | implementation done, review pending>
- **Source session:** <session/task id or a one-line pointer, if one exists>

<One paragraph: what this work is and why it is being handed off. A reader who
knows nothing should finish this paragraph knowing whether it is theirs.>

## Current state

<What is true right now, re-checked — not what you remember doing. Branch, PR,
what is committed vs working-tree, what is deployed, what is running. Each line
carries when it was checked.>

## Next actions (in order)

1. <The first thing the reader does, with the exact command. Startable in five minutes.>
2. <...>

<If an action needs authorization the reader does not have, say so on the action.>

## What changed this session

<What actually landed: files, commits, config. Skip anything that was reverted
or abandoned — that belongs under Traps.>

## Evidence

<Per claim: how you know. Command + result, PR link, live response. Keep it to
claims a reader would otherwise have to re-derive.>

## Unverified

<Everything you believe but did not check, and everything a tool outage or
missing access blocked. If this section is empty, say "None" — and be sure.>

## Settled decisions

<What was decided and why. Mark each as **user decision** or **proposal**. The
reader must not inherit your proposals as requirements.>

## Traps that already cost time

<Failed approaches, wrong assumptions, claims you made and later disproved,
environment gotchas. The single most valuable section: it is the only part the
reader cannot reconstruct from the code.>

## Files, branches, and commands

<Paths, branch names, PR links, the commands to build/test/run. Absolute paths
where the reader will need to open them. No credential values.>

## Dependencies to resume

<Access, tools, env vars, running services — and which of these you confirmed
are present versus assumed.>

## Done when

<The acceptance checks. How the reader knows this work is finished.>

---

This document is context, not authorization. Actions described here still need
their own approval in the session that performs them.

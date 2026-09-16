---
name: handoff-doc
description: Use when work needs to continue somewhere the current conversation cannot follow — handing a project to another agent, another provider, a cloud session, a teammate, or to yourself next week. Trigger when the user says "write a handoff", "handoff doc", "hand this off", "write this up for another agent", "I'm running out of credits/context", "document where we are so someone else can pick it up", or invokes /handoff-doc. Produces one dated markdown document that lets a fresh reader resume without the transcript — current state, evidence, ordered next actions, settled decisions, and the traps that already cost time.
---

# Handoff Doc

Write the knowledge transfer a fresh reader needs to resume this work **without
the conversation**. The reader has no transcript, no scrollback, and no memory of
what you tried. Everything they need is either in this document or lost.

A handoff is not a status report and not a summary. The test is operational: can
someone open this file cold and take the next action correctly?

## When to run this

- The user asks for a handoff / write-up / "document where we are".
- Work is moving to another agent, provider, machine, or session — a cloud
  session, a different CLI, a colleague, or future-you.
- The session is ending with real work unfinished: context is running out,
  credits are low, or the task is blocked on something outside this session.
- Skip it when the work is finished and verified with nothing to resume. That is
  a retrospective (`task-retrospective`), not a handoff.

## What you produce

One markdown file in the handoff directory (see **Output** below), named:

```
YYYY-MM-DD-<slug>-handoff.md
```

`YYYY-MM-DD` is today (`date +%F`). `<slug>` is a short kebab-case handle naming
the project **and** the topic — `walter-claude-activation`, not `handoff` or
`session-2`. The reader scans a directory of these; the filename is the index.

Never overwrite. If the name is taken, append `-2`, `-3`, and say which file you
wrote.

## The template

A blank copy lives in `assets/handoff-template.md`. Read it and fill it in rather
than reconstructing from memory. Drop sections that genuinely do not apply —
an empty heading is noise — but do not drop **Current state**, **Next actions**,
or **Traps that already cost time**. Those three are the document.

Order matters. Front-load what is needed to resume; push supporting detail down
or link it. Some existing handoffs run 700 lines and bury the next action at
line 300; that document has failed at its one job.

## Sourcing the content

Write from what you can point at, not from recollection of the conversation.

- **Current state** — what is true right now. Re-check it: `git status`,
  `gh pr view`, the file that was supposedly edited. A handoff written from
  memory of what you did an hour ago is where stale claims enter the record.
- **Evidence** — for each claim that something works, name how you know: a
  passing command and its output, a merged PR, a live response. Anything you
  believe but did not verify goes under **Unverified**, not under state.
- **Next actions** — ordered, concrete, each one startable. The first action is
  the one the reader takes in the next five minutes. Include the command.
- **Decisions** — separate what the *user decided* from what you *proposed*.
  The reader will otherwise inherit your suggestions as settled requirements.
- **Traps** — failed approaches, corrected assumptions, wrong claims you made
  and later disproved. This is the highest-value section and the one most often
  omitted: it is the only part the reader cannot reconstruct by reading the code.
- **Dependencies to resume** — tools, access, env vars, running services, and
  which of them you confirmed are present.

### Authority and privacy

- A handoff carries **context, not permission**. Say so when it describes
  anything consequential: the next agent still needs its own authorization to
  push, deploy, merge, or install. Never phrase an unfinished step as approved.
- Label every status claim with when it was checked. "Open as of 14:20 EDT" ages
  honestly; "the PR is open" does not.
- No secrets, no tokens, no full transcripts, no unrelated personal
  configuration. Reference a credential by name and location, never by value.

## Output

Write the file to the handoff directory, resolved in this order:

1. A destination the user names explicitly in this conversation, or one the
   project's own instructions establish for handoff documents. An explicit
   project destination wins for this document only — it does not change the
   configured default.
2. `$AGENT_HANDOFF_DIR` if set and non-empty.
3. Otherwise stop and ask the user where handoffs should be written. Do not
   create, choose, or infer a fallback. Once they answer, offer to persist the
   choice as `AGENT_HANDOFF_DIR` so later sessions do not need to ask.

Treat an empty value as unset — an exported empty string means "not configured",
not "write to the empty path". An existing but *empty directory* is a valid
destination; that is a different thing.

The mere presence of a `docs/` directory in the current repo is not a
destination. Some projects do keep handoffs in-repo, but that has to come from
the project's instructions or the user, not from the directory existing.

Write one canonical copy. If the work spans a repo and the handoff directory,
put the document in the resolved directory and add a pointer from the repo —
never two drifting copies. Confirm before writing anything into a repo.

If the resolved destination does not exist or is not writable, say so and ask
for a usable one. Do not invent a fallback path, and do not report a save that
did not happen.

After writing, read the file back and give the user its **absolute** path.

## Keep it lean

Terse. No throat-clearing, no narration of the session's history in order. Every
sentence either tells the reader the state or tells them what to do. If a
paragraph does neither, cut it.

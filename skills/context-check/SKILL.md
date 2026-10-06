---
name: context-check
description: Use when the user asks whether the conversation is running out of room and whether work should move to a fresh session — "is your context getting full?", "do we need a handoff?", "should we start a new conversation?", "are we close to compacting?", "context check", or invokes /context-check. Answers yes or no in the first line, from signals the agent can actually observe (compaction summaries, thread and round count, state that exists only in the transcript), never an invented percentage. The deciding test is what a fresh session could not recover if this conversation vanished now. On yes, routes each at-risk fact to its durable home — the project's own README or instruction file when it belongs there, otherwise a handoff written with handoff-doc.
---

# Context Check

Answer one question definitively: **does this conversation need a handoff right
now?** The size of the context is not the question. A long, many-times-compacted
conversation whose state is all on disk needs no handoff. A short one holding the
only copy of a decision does.

This skill owns the *decision* and the *routing*. Producing the handoff document
belongs to `handoff-doc`; deciding whether a session can be archived belongs to
`session-cleanup`; capturing lessons belongs to `task-retrospective`. Delegate to
them rather than repeating their procedures.

## What you can and cannot see

You generally cannot read your own token count. Do not invent one. "About 80%
full" is a fabricated number dressed as an observation, and the user will plan
around it.

- If a usage figure is genuinely present in your context (the harness printed
  it, or a tool returned it), report it with its source. Otherwise report
  context size as **not observable**.
- Label every signal **observed** (you can point at it in context, on disk, or in
  a command's output right now) or **inferred** (a judgment, or a recollection
  of something a compaction summary has already flattened).

## The signals

Gather these before deciding. Each is cheap.

1. **Compaction.** Is there a summary standing in for earlier conversation — a
   block saying the conversation was summarized or continued from a previous
   context? Count them. Observed when present. Anything that happened before the
   most recent one survives only as that summary's wording, so treat your memory
   of it as inferred.
2. **Threads and rounds.** How many distinct work threads (separate deliverables,
   repositories, or questions) has this session carried, and roughly how many
   revision rounds on each? Observed for the visible transcript, inferred for the
   part behind a compaction.
3. **Degradation.** Have you re-asked for something already given, contradicted a
   settled decision, re-read the same files repeatedly, or been corrected on
   something established earlier? These symptoms are the real cost of a crowded
   context. Report the instances you can point at, or "none observed".
4. **Transcript-only state.** List the durable facts this session produced:
   open PR or issue links, deployed URLs, IDs, decisions the user made, project
   conventions learned the hard way, half-applied changes, verifications still
   owed. For each, **check** whether it already lives somewhere a fresh session
   would look: the repository (README, `AGENTS.md`, `CLAUDE.md`, docs), a commit
   or PR description, a tracker, an existing handoff. Run the check: `git
   status`, `git log`, `gh pr view`, a grep of the docs. "Probably documented"
   is inferred and does not count.

## The decision

Ask: **if this conversation vanished now, what could a fresh session not
recover** from the repository, the remote, the tracker, and the project's own
instruction files?

| Unrecoverable items | Pressure (compaction, degradation, many threads/rounds, or the session is ending) | Verdict |
|---|---|---|
| None | Any | **No.** Size alone never warrants a handoff. |
| Some | Present | **Yes.** Persist them now. The next compaction can drop them without warning. |
| Some | Absent | **No handoff yet.** The facts are still at risk, so the one next action is persisting whichever of them belong in the project's own files. |

When the answer is no but pressure is high, say whether a fresh conversation
would still help: degradation symptoms are a reason to restart even when nothing
needs carrying over. In that case the new session needs only a one-line pointer
(the repository and the next task), not a document.

## When the answer is yes: route each item to its home

Route each unrecoverable item to the place a future reader would look first:

- **The project's own files.** Facts that stay true after this task ends belong
  in the project: how to run or deploy it, its conventions, durable decisions, and
  traps every contributor will hit. Use its README, its agent instruction file
  (`AGENTS.md` or `CLAUDE.md`), or its docs. These are repository changes, so the
  project's own change process applies (branch, review, pull request). If you
  cannot make the change properly right now, list it in the handoff under the
  file it belongs in, so the next session can land it. Never bypass the project's
  process to save context.
- **A handoff document.** Facts about this piece of work in flight belong in a
  handoff: current state, next actions, open PR status, what was tried and
  failed. Use `handoff-doc` to write it, including its rules for choosing a
  destination. Do not hand-roll a handoff here.
- **The tracker.** Follow-up tasks belong in the user's issue tracker or task
  list, not buried in a handoff.

If every item lands in the project's files, no handoff document is needed. Say
so; the verdict is still yes, but the deliverable is the project-file change.

On a yes, do the routing in the same turn rather than ending with "want me to
write it?". The user asked because context is scarce, and a confirmation round
trip spends more of it. The routing rules above still apply: the project's change
process, and `handoff-doc`'s destination question when no destination is
configured.

## Output

Lead with the verdict. Keep the whole report on one screen.

```
<Yes|No> — <one clause: why>

Signals
- Context size: not observable   (or: <figure> — observed, <source>)
- Compaction: <none | N summaries> (observed)
- Threads / rounds: <N threads, ~M rounds> (observed | partly inferred)
- Degradation: <instances | none observed>
- Transcript-only: <N items> (observed: checked <where>)

At risk → home                    (only when there are items)
1. <fact> → <README | AGENTS.md | handoff | tracker>
2. ...

Next: <the single action, already started if the verdict is yes>
```

Cap the at-risk list at five. If there are more, show the five most costly to
lose and add "+N more, all going into the handoff".

## Failure modes this exists to prevent

- **A percentage invented from nothing.** Report context size as not
  observable unless a real figure is in front of you.
- **Yes because the conversation is long.** Length is pressure, not loss.
  Without unrecoverable items, the answer is no.
- **No because "I remember it all."** Memory that has been through a compaction
  is exactly what is at risk. Check the disk, not your recollection.
- **"Already documented" without looking.** Every recoverable claim needs a
  check you actually ran.
- **A handoff that duplicates the README.** Link to project files; do not copy
  them into a one-off document that will drift.
- **An open-ended close.** End on one next action. On a yes, the action is
  already under way.

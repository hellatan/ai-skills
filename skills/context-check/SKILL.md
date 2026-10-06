---
name: context-check
description: Use when the user asks whether the conversation is running out of room and whether work needs to move to a fresh session — "is your context getting full?", "do we need a handoff?", "should we start a new conversation?", "are we close to compacting?", "context check", or invokes /context-check. Decides whether a handoff is needed and proposes where each at-risk fact goes; it writes nothing until the user says go. Answers yes or no in the first line from signals the agent can actually observe, never an invented percentage, using one test — what a fresh session could not recover if this conversation vanished now. On yes, routes each at-risk fact to the project's own files, the tracker, or handoff-doc.
---

# Context Check

Answer one question definitively: **must state leave this conversation now?**
The size of the context is not the question. A long, many-times-compacted
conversation whose state is all on disk needs no handoff. A short one holding the
only copy of a decision does.

The first line is one of three verdicts:

- **Yes** — some fact exists only in this conversation and the context is under
  pressure, so it must be persisted before work continues. Where each fact goes
  (a handoff document, the project's own files, the tracker) is the routing step
  below; a yes does not always mean a handoff document.
- **Not yet** — some fact exists only here, but nothing presses on it. Nothing
  has to move now; persisting the facts that belong in the project is still the
  cheapest time to do it.
- **No** — nothing a fresh session would need exists only here.

This skill owns the *decision* and the *routing*. Producing the handoff document
belongs to `handoff-doc`; deciding whether a session can be archived belongs to
`session-cleanup`; capturing lessons belongs to `task-retrospective`. Delegate to
them rather than repeating their procedures.

## What you can and cannot see

You generally cannot read your own token count. Do not invent one. "About 80%
full" is a fabricated number dressed as an observation, and the user will plan
around it.

- If a usage figure is genuinely present in your context (the harness printed
  it, or a tool returned it), report it with its source and where in the
  conversation it appeared — a figure from many turns ago is stale. Otherwise
  report context size as **not observable**.
- Label every signal **observed** (you can point at it in context, on disk, or in
  a command's output right now) or **inferred** (a judgment, or a recollection
  of something a compaction summary has already flattened).

## The signals

Gather these before deciding. Each is cheap.

1. **Compaction.** Is there a summary standing in for earlier conversation — a
   block saying the conversation was summarized or continued from a previous
   context? Report how many are visible. That number is a lower bound: a later
   summary can absorb earlier ones, and some harnesses trim context without
   leaving a marker, so "none visible" does not prove none happened. Whatever
   preceded the most recent summary survives in your context only as that
   summary's wording, so treat your memory of it as inferred.
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

**Pressure** is your judgment from signals 1–3 and the user's intent, so report
it as inferred and name the signal behind it. Treat it as present when any of
these holds: at least one compaction is visible, at least one degradation
instance is observed, the user says the session is ending or moving elsewhere, or
the session has carried several threads with repeated revision rounds.

## The decision

Ask: **if this conversation vanished now, what could a fresh session not
recover** from the repository, the remote, the tracker, and the project's own
instruction files?

| Unrecoverable items | Pressure | Verdict and next action |
|---|---|---|
| None | Any | **No.** Size alone never warrants a handoff. |
| Some | Present | **Yes.** Propose persisting them now; compaction can drop detail without warning. |
| Some | Absent | **Not yet.** Propose persisting the items that belong in the project's own files or the tracker. If none do, the next action is to continue; the user can run this check again later. |

When the answer is no but pressure is present, say whether a fresh conversation
would still help: degradation symptoms are a reason to restart even when nothing
needs carrying over. In that case the new session needs only a one-line pointer
(the repository and the next task), not a document. If the user is about to
leave or archive, `session-cleanup` owns that decision; point to it.

## When the answer is yes: route each item to its home

Route each unrecoverable item to the place a future reader would look first:

- **The project's own files.** Facts that stay true after this task ends belong
  in the project: how to run or deploy it, its conventions, durable decisions, and
  traps every contributor will hit. Use its README, its agent instruction file
  (`AGENTS.md` or `CLAUDE.md`), or its docs. These are repository changes, so the
  project's own change process applies (branch, review, pull request).
- **A handoff document.** Facts about this piece of work in flight belong in a
  handoff: current state, next actions, open PR status, what was tried and
  failed. Use `handoff-doc` to write it, including its rules for choosing a
  destination. Do not hand-roll a handoff here.
- **The tracker.** Follow-up tasks belong in the user's issue tracker or task
  list, not buried in a handoff. If no tracker is configured, ask; do not invent
  one.

If every item belongs in the project's files, no handoff document is needed. Say
so: the verdict is still yes, and the deliverable is the project-file change.

### One go covers the whole plan

The check itself writes nothing. A question about context is not permission to
write a handoff, edit the repository, or file tracker items, and the handoff
destination may itself be inside the repository.

Instead, the routing table *is* the proposal, and the **Next** line asks for one
go that covers all of it: "Say go to persist all N items as routed above."
One approval for the whole plan costs a single short reply, which is cheaper
than a confirmation per item. On go, write the handoff through `handoff-doc`
(it may still ask for a destination) and make the project-file and tracker
changes through the project's own change process. If the user approves only
part of the plan, list the declined project-file items in the handoff under the
file they belong in, so they survive the session.

A single named next action is not an open-ended "want me to…?". It is the one
step the user approves or declines.

## Output

Lead with the verdict. Keep the whole report on one screen.

```
<Yes|Not yet|No> — <one clause: why>

Signals
- Context size: not observable   (or: <figure> — observed, <source, when>)
- Compaction: <none visible | N visible, a lower bound> (observed)
- Threads / rounds: <N threads, ~M rounds> (observed | partly inferred)
- Degradation: <instances | none observed>
- Transcript-only: <N items> (observed: checked <where>; inferred for items recalled from before a compaction)
- Pressure: <present | absent> (inferred: <which signal>)

At risk → home                    (only when there are items)
1. <fact> → <README | AGENTS.md | handoff | tracker>
2. ...

Next: <the single action — on a yes, "say go to persist all N items as routed above">
```

Cap the at-risk list at five. If there are more, show the five most costly to
lose and add one line counting the rest by destination ("+N more: K → handoff,
J → README").

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
- **An unrequested repository change.** A question about context is not
  permission to branch and edit the project.
- **An open-ended close.** End on one named next action.

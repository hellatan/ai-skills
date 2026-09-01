---
name: session-cleanup
description: Use at the end of a work session to decide whether it is safe to close or archive the conversation. Trigger when the user says "can I archive this", "safe to archive?", "safe to close this out", "anything else before I archive this", "session cleanup", or invokes /session-cleanup. Runs a pre-archive checklist — is the stated work actually verified done, is the git state clean, is a retrospective warranted, are there durable learnings worth saving — then reports a definitive verdict and offers one action per gap. Reports and offers; it does not act without an explicit go. A recurring failure it exists to catch: retro notes or learnings dumped into chat to feel "durable" but never written anywhere that survives the archive.
---

# Session Cleanup

A pre-archive checklist for the end of a work session. It answers one question —
**is it safe to close this conversation?** — by checking the work against
evidence rather than against what was asserted, then reports a verdict and offers
to close each gap it finds.

This skill **reports and offers**. It never commits, pushes, writes files, or
deletes anything on its own — every action waits for the user's explicit go, and
irreversible actions stay gated even then.

## How to run it

Work the four phases below in order. For each, state the finding plainly (a gap,
or "clean"), and where there is a gap, offer the specific action that would close
it. Do not batch the offers into a wall of prompts — surface each phase's result
as you go.

Then end with the **verdict** (see below). Nothing else after the verdict.

### 1. Work actually done

Cross-check every "done" claim made this session against evidence *in the
session* — a command that actually ran with confirmed output, a test that passed,
a change observed in the running app. The failure this catches is
**asserted-but-unverified**: "the fix works" when nothing ever exercised it,
"tests pass" when they were never run, "it's deployed" with no probe of the live
target.

- For each claimed outcome, name the evidence. If there is none, that is a gap.
- Offer to run the missing verification now (run the test, hit the endpoint, open
  the app) rather than carrying the claim into the archive unproven.

### 2. Git hygiene

Report the real git state — never from memory:

- Uncommitted changes and untracked files (`git status`).
- Unpushed commits (`git log @{u}..HEAD`, or note there is no upstream).
- Live PR state, checked now, not recalled — a PR's draft/merged/CI status
  changes out of band, so query it (e.g. `gh pr view`) rather than trusting an
  earlier claim in this conversation.
- Leftover worktrees and stale local branches whose work is already integrated.

**Offer to close each gap by running the fix yourself — do not just hand over a
command for the user to run.** The user invoked this to get to a clean state, not
to collect a to-do list. When there is a leftover worktree or a local branch whose
work is already merged, offer to remove the worktree and delete the merged local
branch for them, then do it on their go. A command block they must copy into their
own terminal is the fallback for when you genuinely cannot run it (wrong cwd, a
tool refuses), not the default.

Three hard limits on what you run:

- **Never remove the worktree the current session is running in.** A worktree is a
  real directory backing this conversation, not just a branch label — removing your
  own working directory saws off the branch you are sitting on (git refuses to
  delete the current working tree, and if forced the session's cwd vanishes
  mid-run). Check first: is the leftover worktree the one this session is in? If it
  is a *different* one, remove it directly. If it is *this* session's own worktree,
  do not remove it inline — instead exit it through the session's own worktree-exit
  mechanism if one exists, or make the removal the very last step run from the main
  checkout (warning that the session's directory will disappear), or hand it off.
  When unsure which case you are in, hand off rather than guess.
- **Follow the project's and the user's own git-workflow conventions** — don't
  invent your own. Those rules live in the project's `CLAUDE.md` and, if the agent
  has one, the user's global memory: how branches are pushed, which pushes are
  allowed, how local vs. remote branches are cleaned up, when cleanup includes
  pruning. Read those first and defer to them; when a convention is unstated, ask.
- **Remote-branch deletion is the exception** — never delete a remote branch
  automatically. Verify it is safe to delete, then hand the user the exact
  `git push origin --delete <branch>` command to run themselves, unless their own
  conventions say otherwise. Local worktree removal and local branch deletion you
  may run on their go; a remote branch you only ever hand off.

For the **integration decision itself** — merge now, open a PR, or keep the branch
going — defer to `superpowers:finishing-a-development-branch`; invoke it rather
than duplicating that judgment here. The mechanical cleanup above (remove worktree,
delete an already-merged local branch) is what this skill offers to run once that
decision is settled.

### 3. Retro warranted?

Quick test: did anything bite this session — a surprise, rework, a blown estimate,
a repeated correction, scope creep? If yes, a retro is worth it; if the work
matched the plan and nothing bit, skip it and say so. `task-retrospective` owns the
authoritative "When to run this" criteria — defer to it rather than maintaining a
parallel list here.

When one is warranted, offer to invoke `task-retrospective` (in this repo:
`skills/task-retrospective/SKILL.md`), which owns the retro format and the
"force the failure signal" discipline. Do not write a retro inline — hand off.

**Chat is not durable.** Printing retro notes into the conversation does not save
them — they are lost the moment the session is archived, which is the exact thing
this skill guards against. A retro counts as done only when it is written to a file
(or the user's chosen retro store) that outlives the conversation. If the user
declines to save it, that is their call — but do not let "I put the notes in chat"
stand in for a saved retro.

### 4. Durable learnings

Surface anything learned this session that is non-obvious and worth keeping past
the conversation — a gotcha, a convention, a footgun, a corrected assumption. For
each, offer the lightest home that fits:

- A note in the user's memory, if the agent keeps one (follow the user's own
  memory conventions — do not save what the repo already records).
- A line in the project's `CLAUDE.md` living-doc section, if the repo has that
  convention and the lesson is repo-specific.
- A filed issue/chip for a follow-up that belongs to the repo.

Confirm before writing into a repo or into memory. Don't duplicate a fact the
codebase or git history already captures.

Same rule as the retro: a learning "captured" only by being mentioned in chat is
not captured — it dies with the conversation. If it is worth keeping, it goes into
a file or memory that survives the archive, or it is consciously let go. Chat is
not a store.

## The verdict

Close with a definitive line, scoped **only to the work in this conversation**.
There are three possible states:

- `⛔ Not yet` — a Phase 1 or Phase 2 blocker: work claimed done but unverified, or
  a dirty/unpushed git state. Name the blocker(s).
- `⏸ One call left` (or more than one) — Phases 1–2 are clean, but a warranted
  retro or a durable learning genuinely worth keeping past the archive is **unsaved
  and undecided**. Name each pending item and the two ways to resolve it: save it,
  or consciously let it go. Not a hard block — but not a clean green either.
- `✅ Safe to archive` — Phases 1–2 are clean AND every warranted retro / identified
  learning has been either **saved** or **consciously released** by the user.

**The distinction that makes this work: "declined" is not "undecided."**

- A retro or learning the user *explicitly chose not to save* is resolved. It does
  not block; note it in one line and let `✅` stand. A retro is not an outlined
  task — never hold the archive hostage to one the user has waved off. But
  "released" means the user accepts the item is lost — **leaving the notes sitting
  in chat is not a release** (see Phase 3): chat does not survive the archive, so
  "I'll just keep it in the thread" is an unsaved-and-undecided item (`⏸`), not a
  conscious drop.
- A retro or learning that is warranted/identified but that the user *has not yet
  ruled on* is **unresolved**. Do not print `✅` over it — that greenlights an
  archive which destroys the exact durable content this skill exists to protect
  (see "Chat is not durable" above). Surface it as `⏸ One call left` and make the
  user own the save-or-drop decision before the clean close.

So Phases 3 and 4 never produce `⛔`, but an *undecided* one holds the verdict at
`⏸` until the user decides. Only Phases 1–2 are hard blockers; Phases 3–4 gate the
final green on a conscious decision, not on the work being written.

The verdict is a yes or a no about *this session's outlined work*, and it stops
there. Do **not** append adjacent improvements, newly noticed drift, or other
things the user could start — even framed as optional, that reopens the thread and
denies the close the user asked for. If something genuinely out of scope is worth
raising, it is a separate question for after the archive, not part of the verdict.

## Keep it lean

This is a gate, not a report. Terse findings, one line per phase where things are
clean. The user invoked this to get to a decision — get them there.

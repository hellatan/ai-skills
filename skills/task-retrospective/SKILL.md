---
name: task-retrospective
description: Use after completing any substantial task — a feature, a bugfix, a multi-step debugging session, a deploy, a client deliverable — to generate a retrospective doc that captures failure signal (not just wins) alongside root causes, action items, and time calibration. Trigger when the user says "write a retro", "do a retrospective", "post-mortem", "retro on this", "what went wrong", "lessons learned", or invokes /task-retrospective. Proactively offer one whenever a task wrapped up with rework, a blown time estimate, a bug that shipped, or an assumption that turned out wrong. A retro that lists only wins is a FAILED retro — the "What went wrong (root causes)" section is mandatory, so dig until you find real failure signal.
---

# Task Retrospective

Generate a lean, honest retrospective after a substantial task. The point is not
to celebrate — it is to extract signal that changes how the next task goes. Wins
are cheap; the value is in root causes and calibration. If you finish a retro and
it reads like a victory lap, you did it wrong.

## When to run this

- The user asks for a retro / post-mortem / "what went wrong" / "lessons learned".
- A task just wrapped that involved rework, a blown estimate, a shipped bug, a
  wrong assumption, or a detour. Offer a retro even if they didn't ask.
- Skip it for trivial one-liners. Retros are for tasks with enough surface area
  to have failure signal worth capturing.

## What you produce

One markdown file, written to the retro directory (see **Output** below), named:

```
YYYY-MM-DD-<slug>-retro.md
```

where `YYYY-MM-DD` is the task's date (use `date +%F` for today) and `<slug>` is
a short kebab-case handle for the task (e.g. `r2-staging-setup`, `auth-refactor`).

## The template

Mirror this structure exactly — same sections, same order. A blank copy lives in
`assets/retro-template.md`; read it and fill it in rather than reconstructing from
memory.

```markdown
# Retrospective — <task title>

- **Date:** <YYYY-MM-DD (HH:MM tz)> → <end, if multi-session>
- **Project:** <project or repo name>
- **Duration:** <elapsed> · <billed/effective, if relevant>
- **Outcome:** <✅ shipped and verified | ⚠️ partial | 🚫 abandoned>

## What shipped (verified)

<One-line summary of what actually landed, then a bullet list. Each bullet is
something you can point to evidence for — a merged PR, a live URL, a passing test,
a devtools observation. Note the verification method. Do NOT list things you
"believe" work; those go under Action items or What went wrong.>

## What went well

<Genuine wins — the practices that paid off and are worth repeating. Keep it
short. This is the least important section; do not pad it.>

## What went wrong (root causes)

<MANDATORY. Numbered list. One entry per failure, mistake, detour, or friction
point. Each entry states what happened, then the **root cause** (the underlying
reason, not the symptom), then the **Fix** (a concrete change that would prevent
a recurrence). If you cannot find anything, you have not looked hard enough — see
"Forcing the failure signal" below.>

1. **<What happened.>** **Root cause:** <why.> **Fix:** <concrete prevention.>

## Assumptions that bit

<Things you assumed that turned out false and cost time. One line each. If none
bit, write "None surfaced" — but check honestly first.>

## Action items

<Checkbox list. Each item is a discrete follow-up. Mark ones already in flight.
Link to filed issues/chips where they exist.>

- [ ] <action> <(status / link if any)>

## Time calibration

- **Estimate:** <the up-front estimate, and where it came from>
- **Actual:** <what it actually took, and the ratio, e.g. ~5×>
- **Drivers:** <what caused the overrun/underrun — the specific factors>
- **Lesson:** <the one calibration takeaway for next time>
```

## Forcing the failure signal

The root-cause section is the whole reason this skill exists. A task with zero
things worth improving essentially never happens — so if your draft has an empty
or thin "What went wrong", interrogate the session before concluding there was
nothing:

- **Rework** — did you write something, then change it? Why was the first version
  wrong? That's a root cause.
- **Estimate miss** — did it take longer (or shorter) than expected? The gap is a
  calibration failure with a cause.
- **Back-and-forth** — did the user correct you, repeat themselves, or express
  frustration? Each correction is signal about a wrong default.
- **Assumptions** — did you assert something (a file exists, a value is set, a
  target is prod) that turned out false? Root cause + fix.
- **Tool/process misuse** — retries, wrong commands, guessed-instead-of-checked,
  skipped verification. All count.
- **Shipped-but-unverified** — anything you claimed worked without proof is a
  latent failure; name it.

State each as *what happened → root cause → fix*. The fix must be specific enough
that following it would actually prevent the recurrence — "be more careful" is not
a fix; "grep across all branches before claiming a feature is missing" is.

## Time calibration discipline

Always include the section, even when the estimate was close. It only becomes
useful over many retros if it is recorded every time.

- Pull the **original** estimate — what you said up front, not a
  post-hoc rationalization. If no estimate was given, say so; that itself is a
  process gap.
- Report **actual** and the **ratio** (actual ÷ estimate).
- Name the **drivers** concretely — "novice-guided provisioning + a stacked-PR
  detour", not "it was harder than expected".
- Close with one **lesson** that would tighten the next estimate.

## Output

Write the file to the retro directory, resolved in this order:

1. `$CLAUDE_RETRO_DIR` if the environment variable is set (this is the user's
   notes vault / handoffs dir).
2. Otherwise fall back to `~/Documents/retros/` and create it if missing. Tell the
   user you used the fallback and that they can set `CLAUDE_RETRO_DIR` to point at
   their vault.

```bash
RETRO_DIR="${CLAUDE_RETRO_DIR:-$HOME/Documents/retros}"
mkdir -p "$RETRO_DIR"
# write to "$RETRO_DIR/$(date +%F)-<slug>-retro.md"
```

### Optional repo pointer

Some lessons are repo-specific (a gotcha about *this* codebase, a CI footgun, a
convention). When a retro contains that kind of durable, repo-scoped lesson,
offer to also surface it where the repo will see it — don't silently duplicate the
whole retro. Pick the lightest touch that fits:

- Add the gotcha to the repo's `CLAUDE.md` "living doc" section, if it has one.
- Append a one-line pointer under a `docs/retros/` index, linking back to the
  vault retro.
- File an issue/chip for an action item that belongs to the repo, not the vault.

Keep the canonical retro in the vault; the repo gets a pointer or the distilled
lesson, not a copy. Confirm with the user before writing into a repo.

## Auto-invocation (not wired)

The user may want this to fire automatically after *every* task via a Stop hook.
That is a real option but has meaningful tradeoffs, and it must not be wired
without the user's explicit go-ahead. The analysis lives in
`references/auto-invocation.md` — read it if the user raises auto-running, and
summarize the tradeoff before touching any config (the `update-config` skill owns
hook changes).

## Keep it lean

A retro is a working document, not a report to management. Terse bullets, no
throat-clearing, no restating the task history at length. The reader is the user
(and future-you) deciding what to do differently — optimize for that.

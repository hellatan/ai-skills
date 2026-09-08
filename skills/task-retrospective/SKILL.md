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
a recurrence), then the three tagging lines described in "Naming the guard"
below. If you cannot find anything, you have not looked hard enough — see
"Forcing the failure signal".>

1. **<What happened.>** **Root cause:** <why.> **Fix:** <concrete prevention.>
   **Guard:** `<file or rule that already covered this>` — <what it keys on, and why that did not fire> | `none`
   **Hook-feasible:** `yes` <the tool call and the condition> | `narrow` <the slice> | `no` — <what makes it uncheckable>
   **Class:** <short mechanism label>, <a second label if it genuinely belongs to two>

## Assumptions that bit

<Things you assumed that turned out false and cost time. One line each. If none
bit, write "None surfaced" — but check honestly first.>

## Action items

<Checkbox list. Each item is a discrete follow-up. Every open item must resolve to
one of three states — filed in a durable tracker (with the link), already in
flight, or consciously dropped. A checkbox with no home is not an action item, it
is a note that will be lost (see "Filing action items" below).>

- [ ] <action> — <filed: link | in flight | dropped: why>

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

## Naming the guard

Every root cause carries three tagging lines. They exist because the single most
valuable thing a retro can report is not *what broke* but **whether something was
already supposed to stop it** — and that fact is invisible from inside any one
retro. Read across a corpus of them it is the whole signal.

### `Guard:` — name the file, not the feeling

Name the rule, memory file, hook, skill step, or `CLAUDE.md` line that already
covered this mechanism, **by filename**, and say what it keys on. If nothing
covered it, write `none` — a real, useful answer, and the one that makes a new
rule *worth considering*. It does not by itself justify writing one: see "Where
the lesson lands", step 0.

The high-value case is a guard that existed and did not fire. When that happens,
the interesting question is never "why didn't I remember?" — it is **what was the
rule keyed to?** A rule triggered by an incidental cue (a ticket named in the
prompt, a symptom looking identical, a particular phrasing) is structurally
unreachable in the case where that cue is absent, which is usually the dangerous
case. A rule keyed to the *action* fires whenever the action happens. So:

> **Guard:** `<rule-file>` — keys on "a PR is named in the prompt"; none was named,
> so the rule was unreachable rather than forgotten.

That sentence is what turns a repeated failure into a fixable one. "I knew the
rule and didn't apply it" is not a root cause; it is the thing to explain.

Name at most one guard. This is a single checkable assertion — a filename that
either exists or does not — deliberately not a taxonomy.

⚠️ **This is a question about the past: what covered this mechanism *when the
failure happened*.** A rule written afterwards, in response to this very incident,
is the guard the failure *produced* — not one it escaped — so `none` is the right
answer there. Check the dates rather than assuming; a guard file's creation date
settles it.

**Before writing `none`, search.** It is the answer that routes toward "write a
new note", so an unsearched `none` is how the same rule gets written twice under
two names.

Resolve your rules directory the same way **Output** below resolves the retro
directory: `$AGENT_RULES_DIR` if set and non-empty, otherwise wherever this agent
keeps durable rules (its memory/config directory, and the repo's `CLAUDE.md`).
Treat an empty value as unset.

```bash
RULES_DIR="${AGENT_RULES_DIR:-$HOME/.claude/memory}"
# Alternation over INDIVIDUAL distinctive words, not a phrase. The duplicate you
# are hunting is worded differently by construction — that is what makes it a
# duplicate under a second name rather than an obvious copy.
grep -rilE "word1|word2|word3" "$RULES_DIR"
```

⚠️ **Confirm the probe can return non-empty before trusting an empty result.** Grep
a term you know is covered; if that also comes back empty, your search is broken,
not your corpus. An empty result and a broken search are the same output — the
failure this document warns about under `Hook-feasible:`, applied to itself.

Then **read the candidates**, do not trust the filename list: a hit whose rule does
not actually cover this mechanism is not a guard. If one does cover it, `none` is
wrong — name it. If the covering file was written *after* the failure, `none` is
still right; step 0 below will find it again when deciding where the lesson goes.

### `Hook-feasible:` — can a machine catch this at the moment it happens?

- **`yes`** only when the failing act is a literal, enumerable argument on a tool
  call: a specific flag value, a command shape, a path prefix. Name the tool call
  and the condition. These are the cases where an automated guard genuinely beats
  a written rule.
- **`narrow`** when a hook covers some slice but not the class. Say which slice.
  A guard sold as covering a class it only partly reaches is worse than none,
  because everyone stops looking.
- **`no`** when the failure is authoring-time reasoning — a judgment about
  evidence, scope, or someone else's system — with no observable tool call and no
  end-of-turn condition that distinguishes the good case from the bad. Say what
  makes it uncheckable.

Be honest about `no`. A hook that cannot fire on the actual failure is not a
guard, it is a new thing to maintain, and proposing one repeatedly for a class
already ruled uncheckable is its own failure loop. Before writing this field,
grep the retro directory (resolved in **Output** below) for the mechanism you are
about to tag:

```bash
grep -rl "Hook-feasible: \`no\`" "$RETRO_DIR" | xargs grep -l "<your Class label>"
```

If a prior retro already ruled this mechanism uncheckable, say so and reuse that
verdict instead of re-proposing automation.

### `Class:` — a hint, never a partition

A short label for the *mechanism*, not the incident: "asserted from a read
narrower than the claim", "check that could not go red", "stale snapshot reused
as live", "someone's prose taken as evidence". Reuse a label you have used before
whenever it fits — matching labels across retros is the entire point.

Two or more labels are allowed and often correct: one incident can be both an
unverified vendor assumption and an unverified claim written into a durable
artifact, distinguished only by venue. Do not force a single bucket. These labels
are hints for a later cross-retro read, not a database key, and the numbered
position of an item is not a stable identifier — never cite a root cause as
"retro X item 3" anywhere durable.

### Why the tagging is worth the three extra lines

One read across 38 retrospectives written over about eight days (September 2026,
a single author's private corpus) sorted them into 13 recurring mechanisms. For
each of those 13, a rule covering it already existed somewhere before its most
recent occurrence — and in the sharpest case a rule was corrected, indexed in
always-loaded context, and produced no behavioral change about a day later. Treat
that as one observation, not a law; it is quoted here because it is the reason
these fields are mandatory rather than optional.

The mechanism argument stands without the statistic. Whether a guard already
existed is invisible from inside a single retro — it only appears when many are
read together, and only if each one says which guard it believes it violated.
Without these lines every retro reads as a fresh incident, the same mechanism
arrives wearing a new costume each time, and the response is always to write one
more note.

## Where the lesson lands

Writing the retro is not the same as durably learning from it, and a new note is
the *default*, not the answer. **Step 0 always runs**; then work items 1–5 in
order and stop at the first that applies — item 1 keys on the step-0 search
result, items 2–4 on `Hook-feasible:`.

0. **First, re-run the search — this list asks a PRESENT-TENSE question.**
   `Guard:` recorded what existed when the failure happened; this asks where the
   lesson goes *now*, and those differ whenever a rule landed in between. Repeat
   the `grep` from "Naming the guard" against the current state before concluding
   nothing covers this. A correct `Guard: none` does **not** license a new note.
   ⚠️ One observed case (September 2026, the same private corpus cited above): a
   retro correctly recorded `none` — its guard had been written the day *after* the
   failure began — then filed a fresh note, duplicating a rule that by then existed
   and had been widened earlier the same day, and reintroducing the narrower
   wording that widening had just retired. Two files, one rule, and the next
   occurrence matches neither cleanly.
1. **A guard that already exists is amended, not duplicated.** If the search above
   names a file **whose rule actually covers this mechanism** — whether or not
   `Guard:` did — the fix usually belongs *in that file*, most often re-keying it from a cue to an action. This takes precedence
   even when `Hook-feasible: yes`: widen the guard you have before adding a second
   one. A new note describing the same mechanism from a new angle makes the next
   occurrence harder to match, not easier.
2. **`Hook-feasible: yes` → propose the check.** Describe the tool call, the
   condition, and the fixtures it would need — a passing case for every legal
   outcome *and* every near-miss it must ignore — then get the user's go-ahead
   before building anything. An untested guard trades a known failure for a silent
   one: a contract check written from the common path can reject correct behavior
   for days without anyone noticing, because its output is indistinguishable from
   a legitimate correction. Automated-guard config is owned elsewhere — see
   "Auto-invocation" below, which routes hook and settings changes to the
   `update-config` skill and requires explicit approval.
3. **`Hook-feasible: narrow` → widen the existing check if its trigger can reach
   the whole mechanism** (same approval path as item 2). If it cannot, name the
   uncovered slice explicitly and treat that slice as `no`. Do not let a guard
   that reaches part of a mechanism be recorded as covering it — that is how a
   class stops being looked at while it is still live.
4. **`Hook-feasible: no` → strengthen the review, not the rulebook.** Failures of
   evidence, scope, and third-party assumption are ones a fresh-context reviewer
   has caught in cases where the author's own review found nothing. Add the
   missing question to whatever brief a reviewer actually receives — a repo's
   automated review prompt (`skills/gh-actions-init/references/claude-code-review.md`,
   "Repo-specific checks") or the standing instructions you hand a review
   subagent. Phrase it as a property to check rather than a list of mechanisms;
   an enumerated list quietly becomes the next blind spot.
5. **Only then, a new note** — and only if step 0's search came back empty. If two
   or three existing notes already describe the same mechanism filed under
   different tools, the right move is to merge them into one rule stated at the
   level of the mechanism, not to add a fourth.

Whichever item you land on becomes an **action item**, resolved under "Filing
action items" below to filed / in flight / dropped like any other. Getting the
user's go-ahead is part of that, not a step around it: the same confirmation rules
apply here as everywhere else in this skill — confirm before writing into a repo,
into the user's tracker, or into agent config. `skills/session-cleanup/SKILL.md`
("Durable learnings") covers the same decision at session close and owns the
end-of-session version of it; this section is the retro-time entry point, not a
second policy.

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

## Filing action items

The retro file is not a tracker. It lives in the retro directory and nobody
reopens it — so an action item that exists *only* as a checkbox in this doc is
already lost. The retro is where you **find** the follow-ups; it is not where they
**live**.

### First, make sure a tracker exists

Filing has no meaning without a place to file *to*. Before you file anything,
resolve the user's durable todo store, in this order:

1. `$AGENT_TODO_STORE` if set and non-empty. This is a **free-text pointer**, not a
   path — it names wherever the user tracks follow-ups: a file (`~/todos.md`), a
   repo for issues (`gh:owner/repo`), a chip/task mechanism (`chips`), anything
   durable. It is store-agnostic on purpose; do not force it into a path shape.
2. A tracker the user has already established through their own memory/config
   conventions, if you can see one.
3. Otherwise it is **unset — and this is a first-run setup step, not a thing to
   guess past.** Prompt the user once: where do their follow-ups go? Do not invent a
   store, and do not let the retro's chat output stand in for one. Once they answer,
   offer to persist the choice so this is asked only once — either by exporting
   `AGENT_TODO_STORE=<their store>`, or, if they can't set env, by recording it
   wherever they keep agent config/memory. Treat an empty value as unset.

A user who consciously says "I don't track todos, drop them" is allowed — that is
the **dropped** state below, made once and explicitly, not a silent default.

### Then resolve every open item

So for every open action item, before the retro is done, drive it to one of:

- **Filed** in the durable store resolved above. Record the link/reference in the
  checkbox. Don't just assert "filed" — the write has to actually happen, and the
  reference has to point at it.
- **In flight** — genuinely already being worked, now, in this session or an open
  PR. Note where.
- **Dropped** — the user consciously decided not to pursue it. Record why in one
  line so the decision is legible later.

"Mentioned in chat" and "written in the retro" are neither filed nor dropped —
they are the default-loss state this section exists to prevent. Confirm the store
before writing into a repo or the user's tracker, but do not let an open item
leave the retro in limbo.

## Output

Write the file to the retro directory, resolved in this order:

1. `$AGENT_RETRO_DIR` if the environment variable is set and non-empty (this is
   the user's chosen notes / retros directory).
2. `$CLAUDE_RETRO_DIR` if set and non-empty — the former name, still honored so
   existing setups keep working. Use it, then mention once that `AGENT_RETRO_DIR`
   is the current name; a silent compat branch is one nobody ever migrates off.
3. Otherwise fall back to `~/Documents/retros/` and create it if missing. Tell the
   user you used the fallback and that they can set `AGENT_RETRO_DIR` to point at
   their preferred directory.

Prefer `AGENT_RETRO_DIR` whenever you tell a user what to set: the retros are
theirs and outlive whichever agent wrote them. Treat an empty value as unset at
both levels — an exported empty string means "not configured", not "write to the
empty path".

```bash
RETRO_DIR="${AGENT_RETRO_DIR:-${CLAUDE_RETRO_DIR:-$HOME/Documents/retros}}"
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
  canonical retro.
- File an issue/chip for an action item that belongs to the repo, not the retro
  directory.

Keep the canonical retro in the retro directory; the repo gets a pointer or the
distilled lesson, not a copy. Confirm with the user before writing into a repo.

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

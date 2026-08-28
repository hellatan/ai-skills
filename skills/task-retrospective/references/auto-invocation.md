# Auto-invocation: Stop hook vs. manual

Should `task-retrospective` run automatically after every task instead of being
invoked per-task? This is the tradeoff analysis. **Do not wire a hook without the
user's explicit approval** — hook changes go through the `update-config` skill,
which edits `settings.json` (the harness runs the hook, not Claude).

## The two models

**Manual (current default).** The user (or Claude, proactively) invokes the skill
when a task is worth a retro. Nothing fires on its own.

**Automatic (Stop hook).** A `Stop` hook runs at the end of every session/turn and
triggers a retro unconditionally.

## Why automatic is tempting

- **No reliance on memory.** Behavioral rules that live only in memory files don't
  self-enforce; a hook does. (This is the exact failure mode that motivated the
  ADHD-mode/limits SessionStart hook.)
- **Full coverage.** Every task gets calibration data, so the time-calibration
  history actually accumulates instead of being sampled ad hoc.
- **Catches the retros you'd skip** — precisely the ones after a rough task, when
  you least feel like writing one, are the most valuable.

## Why automatic is risky

- **Most Stop events are not task completions.** A `Stop` hook fires on every turn
  end, including mid-task pauses, clarifying questions, and pure-conversation
  replies. A retro after "what's the weather in your codebase" is noise, and worse,
  it trains the reader to ignore retros. There is no reliable signal at the Stop
  boundary for "a substantial task just finished."
- **Cost and latency.** Generating a doc on every Stop burns tokens and adds a
  write to every turn, most of which don't warrant one.
- **Dilution.** A retro's value is that it's reserved for tasks with real failure
  signal. Auto-firing on trivial turns produces thin, template-filled retros that
  bury the ones that matter.
- **Directory churn.** The retro directory fills with low-value `-retro.md` files
  that have to be pruned.

## Recommendation

Keep it **manual + proactive**: the skill stays invocable, and Claude offers a
retro when a task visibly wrapped with rework, a blown estimate, or a shipped bug.
This captures the high-value retros without the noise and cost of firing on every
turn.

If the user still wants automation, the least-bad version is **not** a blanket
Stop hook but a **gated** one — e.g. a hook that only proposes a retro when the
session shows completion signal (a merged PR, a "done"/"shipped" from the user, a
task that ran past some duration). That gating logic is non-trivial and belongs in
its own design pass. Until then, manual is the honest default.

## If the user approves a hook

Hand off to the `update-config` skill to add the hook to `settings.json`. Do not
edit settings directly from this skill. Surface the exact hook config in chat
before it's written, and note that the gating (if any) is best-effort.

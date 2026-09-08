# Retrospective — <task title>

- **Date:** <YYYY-MM-DD (HH:MM tz)> → <end, if multi-session>
- **Project:** <project or repo name>
- **Duration:** <elapsed> · <billed/effective, if relevant>
- **Outcome:** <✅ shipped and verified | ⚠️ partial | 🚫 abandoned>

## What shipped (verified)

<One-line summary of what actually landed, then a bullet list. Each bullet is
something you can point to evidence for — a merged PR, a live URL, a passing test,
a devtools observation. Note the verification method. Do not list things you only
believe work.>

-

## What went well

<Genuine wins worth repeating. Keep it short; do not pad.>

-

## What went wrong (root causes)

<MANDATORY. Numbered. One entry per failure/detour/friction. What happened →
root cause → fix → the three tagging lines (see SKILL.md, "Naming the guard").
If empty, you have not looked hard enough.>

1. **<What happened.>** **Root cause:** <why.> **Fix:** <concrete prevention.>
   **Guard:** `<file or rule that already covered this>` — <what it keys on, and why that did not fire> | `none`
   **Hook-feasible:** `yes` <the tool call and the condition> | `narrow` <the slice> | `no` — <what makes it uncheckable>
   **Class:** <short mechanism label>, <a second label if it genuinely belongs to two>

## Assumptions that bit

<Things you assumed that turned out false and cost time. "None surfaced" only
after checking honestly.>

-

## Action items

- [ ] <action> <(status / link if any)>

## Time calibration

- **Estimate:** <up-front estimate + where it came from>
- **Actual:** <what it took + ratio, e.g. ~5×>
- **Drivers:** <specific factors behind the gap>
- **Lesson:** <one calibration takeaway>

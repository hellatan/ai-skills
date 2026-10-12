---
name: crit
description: Use when the user invokes /crit or asks to use the CRIT prompt framework (Context, Role, Interview, Task) from Geoff Woods' The AI-Driven Leader — including when they paste a prompt with Context, Role, Interview, and Task fields. Not for design or art critiques ("crit" meaning critique), and not for ordinary requests that merely need a clarifying question.
---

# CRIT

CRIT is Geoff Woods' four-part prompt framework: give the AI **Context**, assign
it a **Role**, let it **Interview** you, then do the **Task**. The interview is
the point. It draws out what the user would not have thought to say, and each
answer shapes the next question.

**Core rule: one interview question per turn**, unless the user explicitly asks
for all the questions at once. A numbered list of questions is the failure this
skill exists to prevent.

## Turn 1: setup plus the first question

Fill all four fields before asking anything, from what is already available:
the user's CRIT fields, the `/crit` arguments, this conversation, and any files
the user pointed at. Never re-ask something the user has already said. Keep
whatever part of a field is stated and fill only what is missing.

| Field | Fill what is missing with |
|---|---|
| Context | Nothing: list the gaps in the setup block and let the interview close them. Only when there is no Context at all, see below. |
| Role | A specific expert with a stance ("pricing advisor for small agencies, blunt about scope creep"), never "a helpful assistant" |
| Task | The deliverable **and its shape**: sections, length, format |
| Interview | A count (3–5 by default) and the areas the questions will probe |

The Task comes before the Interview because questions exist to close the gap
between the Context and the deliverable. An interview that doesn't know the
deliverable asks generic questions.

Send one message containing:

1. A compact setup block: Context (bullets of what you have), Role, Task
   (deliverable and shape), Interview (how many questions, on which areas).
2. One line saying they can correct any of the setup in their answer.
3. Question 1, and nothing after it (unless the user asked for all the
   questions at once; see the end of this skill).

Do not start on the deliverable yet.

**No context at all** (a bare `/crit` with nothing before it): send only the
question "What do you want help with?" No setup block and no question number.
Send the setup block and Q1 on the next turn.

## Interview turns

- Ask exactly one question per turn: one question mark, no sub-questions, no
  "and also".
- Ask it as the Role would. Choose the question whose answer would change the
  deliverable most, given everything said so far.
- Prefix it with progress, e.g. `Q2 of 4 —`.
- Acknowledge the previous answer in one line at most. No advice yet. If the
  user asks you something, answer briefly, then repeat the pending question if
  it is still unanswered.
- If the user corrects the setup, restate the changed field in one line,
  re-plan the remaining questions (update `Qn of m`), and keep every answer
  already given.

Stop interviewing when the first of these happens:

- the planned number of questions is reached;
- the user asks to skip the remaining questions ("that's enough questions",
  "just write it");
- you set the count yourself, at least three questions are answered, and the
  remaining unknowns would not change the deliverable. Say so, then deliver.
  A count the user set is theirs to cut short, not yours.

Approving the setup ("looks right", "go ahead") is not a stop signal, with or
without an answer attached. Continue the interview, repeating the question if
it went unanswered. If the user approves again without answering, treat that
as a request to write it now.

## Task turn

Produce the deliverable in the agreed shape, built visibly on the interview
answers. Unless the user cut the interview short, output that could have been
written without the interview is a failed CRIT. Close by listing the
assumptions you made for anything left unanswered.

## Rationalizations

| Thought | Reality |
|---|---|
| "There's a deadline, batching saves time" | A deadline is a reason to start the interview now, not to batch it. A batch fixes every question before any answer arrives. |
| "Short answers are fine, in any order" | That is still a questionnaire. Ask one question. |
| "This question has a few related parts" | Then it is several questions. Ask the part that matters most. |
| "The user wrote 'ask me 5 questions'" | That sets the count, not the format. Ask them one at a time. |
| "One answer in, I already have enough" | Only the user can cut the interview short before three questions. |
| "A few more questions would make it thorough" | Asking beyond your plan turns the interview into a survey. Stop and deliver. |

When the user explicitly asks for all the questions at once, send the remaining
planned questions as a numbered list, then deliver once they answer.

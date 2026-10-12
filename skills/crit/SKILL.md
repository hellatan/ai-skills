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
the user pointed at. Never re-ask something the user has already said.

| Field | If it is stated | If it is missing or partial |
|---|---|---|
| Context | Use it | See "No context at all" below |
| Role | Use it | Propose a specific expert with a stance ("pricing advisor for small agencies, blunt about scope creep"), never "a helpful assistant" |
| Task | Use it, adding a shape if none was given | Propose the deliverable **and its shape**: sections, length, format |
| Interview | Use its count and areas | Plan 3–5 questions and name the areas they will probe |

The Task comes before the Interview because questions exist to close the gap
between the Context and the deliverable. An interview that doesn't know the
deliverable asks generic questions.

Send one message containing:

1. A compact setup block: Context (bullets of what you have), Role, Task
   (deliverable and shape), Interview (how many questions, on which areas).
2. One line saying they can correct any of the setup in their answer.
3. Question 1, and nothing after it.

Do not start on the deliverable yet.

**No context at all** (a bare `/crit` with nothing before it): send only one
question asking what they are working on and what they want out of it. No setup
block and no question number. Send the setup block and Q1 on the next turn.

## Interview turns

- Ask exactly one question per turn: one question mark, no sub-questions, no
  "and also".
- Ask it as the Role would. Choose the question whose answer would change the
  deliverable most, given everything said so far.
- Prefix it with progress, e.g. `Q2 of 4 —`.
- Acknowledge the previous answer in one line at most. No advice yet. If the
  user asks you something, answer briefly, then ask the next question.
- If the user corrects the setup, restate the changed field in one line,
  re-plan the remaining questions (update `Qn of m`), and keep every answer
  already given.

Stop interviewing when the first of these happens:

- the planned number of questions is reached;
- the user says they are done with the interview ("that's enough", "go ahead").
  Approving the setup without answering the question is not a stop signal:
  repeat the question;
- at least three questions are answered and the remaining unknowns would not
  change the deliverable. Say so, then deliver.

## Task turn

Produce the deliverable in the agreed shape, built visibly on the interview
answers. Output that could have been written without the interview is a failed
CRIT. Close by listing the assumptions you made for anything left unanswered.

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

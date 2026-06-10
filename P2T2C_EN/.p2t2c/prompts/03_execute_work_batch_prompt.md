# Prompt 03 - Execute Work Batch

Goal: execute one goal-aligned work batch that can be accepted as a whole.

Preconditions:

- R0 has completed risk routing.
- R1/R2 has a valid `CPK-*`.
- R2 `gate_a` is not `pending`.

For R1/R2, create or update a compact trio in `specs/{NNN-feature}/`:

- `spec.md`: goal, CPK and Truth references, acceptance behavior.
- `plan.md`: implementation strategy, impact, and risks.
- `tasks.md`: related tasks and batch-level acceptance commands.

Execution rules:

- A batch may contain multiple related tasks serving the same goal.
- Follow existing codebase patterns and continuously check against CPK, spec, and Truth.
- Do not require per-task Actual results, `Acceptance scope`, or one-task pauses.
- Return to intent admission when discovering a new semantic boundary, Truth conflict, high-risk concern, or dangerous operation.

Report the batch scope, changed files, planned verification set, and newly discovered risks.

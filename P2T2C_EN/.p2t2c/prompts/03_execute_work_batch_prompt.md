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
- For automatable R1/R2 behavior, use `skills/risk-aware-tdd/SKILL.md`: define behavior from Truth/CPK/spec, observe a focused test fail, make the minimum implementation, then verify it passes. Record an explicit exemption and alternative evidence for generated output, pure configuration, exploration, or impractical automation.
- Read `skills/workspace-isolation/SKILL.md` before R2, parallel, or explicitly isolated work. With `isolation: auto`, prefer host-managed isolation; otherwise record the current branch and applicable clean baseline. Parallel execution is limited to independent R2 tasks with non-overlapping ownership.
- For R1 production-code changes and all R2 work, reserve an independent two-pass review checkpoint before closure. Do not require per-task commits or per-task Actual records.
- Do not require per-task Actual results, `Acceptance scope`, or one-task pauses.
- Return to intent admission when discovering a new semantic boundary, Truth conflict, high-risk concern, or dangerous operation.

Report the batch scope, changed files, TDD evidence or exemptions, isolation/baseline state, planned verification set, and newly discovered risks.

# Prompt 05 — Execute One Task

Goal: execute only the specified Task in `tasks.md`.

First read `AGENTS.md`, then complete the Required Reading listed there.

Additional reads for this stage:

- Related SoT
- Current feature `spec.md``spec.md`
- Current feature `plan.md``plan.md`
- Current feature `tasks.md``tasks.md`

Rules:

- Implement only the user-specified Task.
- Do not implement features outside the Task.
- Do not add rules not defined by Truth.
- Run the Task acceptance command when complete.
- Backfill Actual results in `tasks.md`.
- If the acceptance command fails, do not expand scope to fix other Tasks; stop and report evidence first.

Must stop:

- A key Plan assumption becomes invalid.
- Implementation requires a new rule not defined by SoT.
- Acceptance fails.
- Truth Drift appears.

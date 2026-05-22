# Prompt 05 — Execute One Task

Goal: execute only the specified Task in `tasks.md`.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Governance reading (RULE-GOV-012): this stage's phase token is `single_task`. Read only the governance Rule Blocks on the `single_task:` line of `.p2t2c/generated/phase_rules.txt`. Do not read all of `P2T2C_GOVERNANCE.md`, and do not read `P2T2C_GOVERNANCE_HISTORY.md`.

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

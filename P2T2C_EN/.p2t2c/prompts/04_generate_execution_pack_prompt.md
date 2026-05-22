# Prompt 04 — Generate Execution Pack

Goal: generate `spec.md / plan.md / tasks.md` from confirmed and applied Truth.

Prerequisites:

- Gate A has been confirmed.
- Change Pack Truth Patch has been applied.
- Current Truth / ADR already defines the rules required by this feature.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Governance reading (RULE-GOV-012): this stage's phase token is `execution_pack`. Read only the governance Rule Blocks on the `execution_pack:` line of `.p2t2c/generated/phase_rules.txt`. Do not read all of `P2T2C_GOVERNANCE.md`, and do not read `P2T2C_GOVERNANCE_HISTORY.md`.

Additional reads for this stage:

- Related SP
- Related ADR
- `.p2t2c/templates/execution/spec.md`
- `.p2t2c/templates/execution/plan.md`
- `.p2t2c/templates/execution/tasks.md`

Generate:

```text
specs/{NNN-feature}/spec.md
specs/{NNN-feature}/plan.md
specs/{NNN-feature}/tasks.md
```

Requirements:

- `spec.md` must include Truth references.
- Each EARS acceptance statement in `spec.md` must end with the `[RULE-...]` identifier(s) it verifies, and each tagged identifier must appear in the Truth References table (RULE-GOV-011).
- `plan.md` states strategy only; do not write full code.
- `tasks.md` must split work into independently acceptable tasks.
- Each task must have an acceptance command or executable acceptance step, and that step must name the same `RULE-...` identifier it accepts (RULE-GOV-011).
- Do not add business rules not defined by Truth in spec / plan / tasks.
- Wait for explicit user instruction before coding unless the user already authorized automatic execution.

Must stop:

- Truth Patch has not been applied.
- Execution docs require a new rule not defined by SoT / ADR.
- SP, Truth, and ADR conflict.

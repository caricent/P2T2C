# Prompt 04 — Generate Execution Pack

Goal: generate `spec.md / plan.md / tasks.md` from confirmed and applied Truth.

Prerequisites:

- Gate A has been confirmed.
- Change Pack Truth Patch has been applied.
- Current Truth / ADR already defines the rules required by this feature.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Additional reads for this stage:

- Related CP
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
- `plan.md` states strategy only; do not write full code.
- `tasks.md` must split work into independently acceptable tasks.
- Each task must have an acceptance command or executable acceptance step.
- Do not add business rules not defined by Truth in spec / plan / tasks.
- Wait for explicit user instruction before coding unless the user already authorized automatic execution.

Must stop:

- Truth Patch has not been applied.
- Execution docs require a new rule not defined by SoT / ADR.
- CP, Truth, and ADR conflict.

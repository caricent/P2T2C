# Prompt 01 - Intent Admission

Goal: confirm that the current intent is clear enough, does not conflict with current Truth, and can enter risk routing.

Read first:

- `P2T2C_AGENTS.md`
- `.p2t2c/project_config.yaml`, or its example if missing
- `docs/sot/manifest.yaml`
- SoT, ADRs, implementation, and tests directly related to the intent

Input may be a user instruction, Issue, or optional `SP-*`. Do not require an SP only to enter the workflow.

Actions:

1. Summarize the goal, non-goals, and acceptance outcome.
2. Check ambiguity, Truth/ADR conflicts, and impact.
3. Identify product, architecture, security, permission, or data semantics that require a human choice.
4. Continue directly to risk routing when intent is clear and conflict-free.

Pause only when:

- A material ambiguity changes the implementation outcome.
- Intent conflicts with current Truth or an accepted ADR.
- Continuing would invent an undecided business rule.
- A dangerous operation or external permission is required.

Output: admission decision, evidence, and an intent summary for stage 2.

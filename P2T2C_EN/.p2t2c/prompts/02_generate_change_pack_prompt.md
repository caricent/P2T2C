# Prompt 02 — Generate Change Pack (No File Changes)

Goal: generate a Change Pack from a Submit Proposal and present Gate A as explicit human decision options when Gate A is needed.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Governance reading (RULE-GOV-012): this stage's phase token is `change_pack`. Read only the governance Rule Blocks on the `change_pack:` line of `.p2t2c/generated/phase_rules.txt`. Do not read all of `P2T2C_GOVERNANCE.md`, and do not read `P2T2C_GOVERNANCE_HISTORY.md`.

Additional reads for this stage:

- Current SP file
- Related SoT
- `.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`

The Change Pack must include:

1. Admission Summary
2. Impact Review
3. Change Pack Body
4. Gate A decision options and required human action

Rules:

- Fill `Admission Summary` first and decide whether the Proposal may enter Truth.
- Admission decision must be one of: `READY`, `NEEDS_PROPOSAL_REPAIR`, `CONFLICTS_WITH_TRUTH`, `CONFLICTS_WITH_IMPLEMENTED_TRUTH`, `ADR_REQUIRED`, `OUT_OF_SCOPE`.
- If decision is `READY`, use Fast Path and generate Truth Patch Candidate plus Execution Pack Summary.
- If decision is not `READY`, do not generate an applicable Truth Patch Candidate; write `Truth Patch Candidate: Not generated` and output one unified `Blocking Brief`.
- Do not expand multiple Repair / Conflict / ADR templates at the same time when blocked.
- Human questions must be decision options; list at most 5 high-impact questions.
- If Gate A is needed after the Change Pack, ask the human to choose exactly one bounded option. Use selectable options when the interface supports them; otherwise list the options and wait for the human choice.

Forbidden:

- Do not modify files.
- Do not generate code.
- Do not accept ADRs by yourself.
- Do not put business rules into Agent rules, prompts, tests, or code comments.

If any Stop-the-line Checklist item is Yes, Admission decision must not be `READY`.

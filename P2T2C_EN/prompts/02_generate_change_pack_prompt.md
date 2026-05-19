# Prompt 02 — Generate Change Pack (No File Changes)

Goal: generate a Change Pack from a Change Proposal for human Gate A review.

First read `AGENTS.md`, then complete the Required Reading listed there.

Additional reads for this stage:

- Current CP file
- Related SoT
- `templates/change_pack/CHANGE_PACK_TEMPLATE.md`

The Change Pack must include:

1. Admission Summary
2. Impact Review
3. Change Pack Body
4. Required human action for Gate A

Rules:

- Fill `Admission Summary` first and decide whether the Proposal may enter Truth.
- Admission decision must be one of: `READY`, `NEEDS_PROPOSAL_REPAIR`, `CONFLICTS_WITH_TRUTH`, `CONFLICTS_WITH_IMPLEMENTED_TRUTH`, `ADR_REQUIRED`, `OUT_OF_SCOPE`.
- If decision is `READY`, use Fast Path and generate Truth Patch Candidate plus Execution Pack Summary.
- If decision is not `READY`, do not generate an applicable Truth Patch Candidate; write `Truth Patch Candidate: Not generated` and output one unified `Blocking Brief`.
- Do not expand multiple Repair / Conflict / ADR templates at the same time when blocked.
- Human questions must be decision options; list at most 5 high-impact questions.

Forbidden:

- Do not modify files.
- Do not generate code.
- Do not accept ADRs by yourself.
- Do not put business rules into Agent rules, prompts, tests, or code comments.

If any Stop-the-line Checklist item is Yes, Admission decision must not be `READY`.

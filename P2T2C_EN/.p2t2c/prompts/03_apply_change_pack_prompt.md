# Prompt 03 — Apply Approved Change Pack

Use only after Gate A has been confirmed by a human.

Prerequisites:

- Change Pack `Admission decision` must be `READY`.
- Gate A must explicitly choose `Approve and apply Truth Patch`.
- Change Pack must not contain an unresolved `Blocking Brief`.
- If `Truth Patch Candidate: Not generated` exists, stop and do not apply SoT / ADR changes.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Governance reading (RULE-GOV-012): this stage's phase token is `apply_change_pack`. Read only the governance Rule Blocks on the `apply_change_pack:` line of `.p2t2c/generated/phase_rules.txt`. Do not read all of `P2T2C_GOVERNANCE.md`. Read `P2T2C_GOVERNANCE_HISTORY.md` only when triaging a lifecycle conflict.

Additional reads for this stage:

- Approved Change Pack
- Related SP
- `.p2t2c/templates/truth/SOT_DOCUMENT_TEMPLATE.md`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`
- `docs/sot/manifest.yaml`

Actions:

1. Apply the Truth Patch to `docs/sot/`.
2. If the Change Pack includes an ADR action, create or update `docs/adr/` only when Gate A explicitly confirmed the full ADR content and no blocker remains; otherwise stop. Skip ADR when no ADR action exists.
3. Update `docs/sot/manifest.yaml`.
4. Run `make check`.

Forbidden:

- Do not put business rules in `P2T2C_AGENTS.md`, project-owned `AGENTS.md`, prompts, tests, or code comments.
- Do not let prompts / tests / specs define a new rule by themselves.
- If a new conflict appears during application, stop immediately.
- If the Change Pack contains a `Blocking Brief`, stop and require human resolution first.
- If `make check` fails, stop and report failure evidence.

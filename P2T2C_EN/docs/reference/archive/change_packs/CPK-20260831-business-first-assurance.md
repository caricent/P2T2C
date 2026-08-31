---
artifact: change_pack
schema_version: 3
id: CPK-20260831-business-first-assurance
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-adaptive-v2
execution_shape: architectural
production_code_change: true
multi_agent: true
work_pack: specs/015-business-first-assurance/work.md
implementer: root-controller
tdd_policy: required
governance_change: true
specialist_review_required: true
truth_patch_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_patch_digest: 9976fd86c2071c54d7fc4a0bc9eeb324aa93b5fd2f870b8dc83dd783e94abf96
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3,W4
legacy_startup_evidence: false
---

# CPK-20260831-business-first-assurance

## Intent and boundary

- Release P2T2C 0.15 with Explore, Propose, Apply, optional Verify, and Archive as the default actions.
- Reduce active documents to docs/proposals, docs/specs, and docs/sot; SP carries why/what, design carries how, and tasks tracks implementation and completion.
- Withdraw the unreleased assurance/proof/event-v2/receipt-v3/next/finish design; project tests, CI, and code review remain in the project engineering system.
- Preserve R0/R1/R2, one human decision, dangerous-operation authorization, user-change protection, and 0.14.x legacy closure compatibility.
- Add explicit, reversible docs-migrate; normal upgrade never moves project-owned documents.

## Routing and acceptance

- R2 / architectural: governance Truth, active-document layout, checker, Archive, migration transactions, install/upgrade, and bilingual release all change.
- New R1/R2 may use only SP + design.md + tasks.md; R0 is zero-artifact.
- Archive executes no project command and only atomically updates tasks status after known blockers clear.
- Open CPK v3/event v1/receipt v1/v2 work remains closable unchanged.
- Bilingual check, core/security/transaction/migration/locale smoke, and the real 0.14.1 upgrade fixture pass.

## Truth Patch and ownership

- Truth Patch: RULE-GOV-001 through 020 for core actions, three-domain documents, Decision Records, quality boundaries, legacy compatibility, and explicit migration.
- W1: Truth, Decision Records, SP/design/tasks contracts, and templates.
- W2: Documents validator, Archive, and CLI.
- W3: docs-migrate, install/upgrade, path/transaction safety, and legacy compatibility.
- W4: README/AGENTS, manifest/inventory, bilingual parity, and release smoke.
- One integration controller: root-controller; batch write scopes do not overlap.

## Method checkpoints

- This 0.15 change still closes under adaptive-v2 CPK v3 and does not use the new core to lower its own evidence requirements.
- W1-W4 independent reviews plus global and compatibility-specialist review clear before legacy full/governance verification.
- No proposal accepts implementation drift and writes it back into Truth, so Gate B is not triggered.

## Blockers

- None.

## Closure evidence

Await implementation, independent review, final verification, and legacy R2 closure.

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

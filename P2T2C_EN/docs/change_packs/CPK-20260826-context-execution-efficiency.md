---
artifact: change_pack
schema_version: 3
id: CPK-20260826-context-execution-efficiency
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: architectural
production_code_change: true
multi_agent: true
work_pack: specs/0141-context-execution-efficiency/work.md
implementer: root-controller
tdd_policy: required
governance_change: true
specialist_review_required: true
truth_patch_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_patch_digest: dffca2ddffd0f0dd4c6d8f5ed222866d9acd0462cd231caccfd64085a69cd57c
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3
legacy_startup_evidence: false
---

# CPK-20260826-context-execution-efficiency

## Intent and boundary

- Deliver 0.14.1-A and 0.14.1-B: reduce hot context and duplicate execution while preserving output quality, Truth authority, Gate A/B, review roles, two repair rounds, and final-tree evidence.
- Keep `methodology.profile: p2t2c-adaptive-v2`; use release/capability/receipt versions to identify the engine change.
- Explicit non-goal: 0.14.1-C. Do not add Agent dispatch thresholds, model/effort routing, review-capsule experiments, compaction policy, or weaker review semantics.
- The user supplied the complete desired boundary, so Gate A is satisfied.

## Route and acceptance

- R2 / architectural: Governance Truth, evidence storage, checker/close, install/upgrade, bilingual release surfaces, and verification orchestration change together.
- Context acceptance: deterministic `context`, `status`, and `evidence summary` JSON; three phase skills; default fixed context at least 50% below 0.14; no raw intent/event/output in hot views.
- Evidence acceptance: new close writes receipt v2 plus content-addressed sidecar; target proof is under 3 KiB; historic inline receipt v1 remains valid and untouched.
- Engine acceptance: one-process checker index, safe historical cache, coverage-aware batch verify, one semantic close preparation, cold failure logs, and split/parallel release smoke without removing negative fixtures.
- Quality gates: final full + governance on one tree, W1/W2/W3 batch review, final global review, and evidence/install/migration specialist review; all findings zero.

## Truth Patch and ownership

- Truth Patch: RULE-GOV-017 and RULE-GOV-018 in `docs/sot/governance/P2T2C_GOVERNANCE.md`.
- W1: context delivery, defaults/manifest, phase skills, compatibility prompts, localized documentation and schemas.
- W2: evidence/checker/run/verify/close engine, sidecar and cache safety.
- W3: smoke suites, real 0.14.0 migration fixture, installer/upgrader inventory, versions, checksums and release notes.
- Single integration controller: `root-controller`; write ownership must not overlap.

## Method checkpoints

- TDD must demonstrate missing new wires first, then cover sidecar substitution, stale cache, coverage forgery, transaction rollback, bounded output and historical compatibility.
- Read-only exploration may run in parallel. Implementers and reviewers do not recursively fan out.
- Only accepting implementation drift into Truth would trigger Gate B; no such drift is currently proposed.

## Blockers

- None. A byte-exact pre-0.14.1 release fixture was frozen before this Truth Patch because 0.14.0 is not committed in Git history.

## Closure Evidence

Pending implementation, independent review, final verification and automatic R2 close.

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

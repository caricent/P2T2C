---
artifact: change_pack
schema_version: 3
id: CPK-20260826-adaptive-v2
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-adaptive-v2
execution_shape: architectural
production_code_change: true
multi_agent: true
work_pack: specs/014-adaptive-v2/work.md
implementer: root-controller
tdd_policy: required
governance_change: true
specialist_review_required: true
truth_patch_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_patch_digest: a7d1be7c1869ab4ef5025c507e4673a3c46eb524fc35b038235318e6e5a04012
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3
legacy_startup_evidence: true
---

# CPK-20260826-adaptive-v2

## Intent and Boundaries

- Goal: Increase P2T2C production efficiency through adaptive autonomy, scaled artifacts, and machine evidence while preserving AI output quality, Truth authority, and R2 human control.
- Non-goals: Bundle Superpowers, let spec/CPK override SoT, remove final fresh verification, delegate dangerous or undecided semantics to Agents, or rewrite historical 013 artifacts.
- Source: The complete v0.14 implementation instruction given by the user on 2026-08-26; complete semantics were decided, so Gate A is satisfied.

## Routing

- Risk and rationale: R2 because governance Truth, Gate B, artifact contracts, evidence schema, install/upgrade behavior, and Agent authority boundaries change.
- Execution shape and rationale: architectural because the change crosses bilingual roots, checker/close, install/upgrade, configuration, and behavior eval with multiple ownership batches and final integration.
- Upgrade conditions: Already at the strongest shape; stop at Gate A if a new undecided security, permission, or data semantic appears.
- Related Truth / ADRs: RULE-GOV-001, 003, 014, 015, 016; ADR-014.

## Acceptance and Implementation Strategy

- Targets pending real A/B: reduce bounded R1 handwritten persistent artifacts from five to one; at least 90% of R0 has zero handwritten workflow docs; workflow-doc volume falls at least 60% and total cycle time at least 30%. No target is claimed as met.
- Quality non-inferiority pending evaluation: defect escape, rework, and Truth Drift do not exceed v0.13 control; 100% of applicable verification and required review binds the final diff/tree.
- Define deterministic fixtures and real-Agent scenarios comparing v0.13 control to adaptive-v2 treatment; this change only defines the eval and does not claim a real LLM eval was run.
- Verification: mandatory mapping for every changed path; complete full + governance on one final tree; CLI uses configured profile+command ID only.

## Truth Patch

Prepared for atomic application when this R2 batch integrates:

- Combine five governance states into three runtime loops.
- Add risk x execution-shape routing with monotonic upgrades.
- Apply the R0 / bounded R1 / architectural / R2 artifact matrix and narrow Gate B.
- Apply CPK/CR v3, contract-digest/local-consistency receipt, verification profiles, and one `.p2t2c/managed-files.txt` inventory.
- Apply adaptive review, parallelism, fan-out, model-tier, event-wait, and two-round scoped-repair boundaries.

## Execution and Ownership

- Ownership batches: W1 governance/bilingual docs and upstream facts; W2 machine evidence/checker; W3 install/upgrade/managed files/config. IDs are unique and every batch requires batch review.
- File ownership: W1-W3 are exclusive. Final integration does not create a fourth ownership batch; one controller merges and triggers global/specialist plus full/governance.
- Isolation and baseline: Host-managed shared workspace with disjoint paths; preserve pre-existing user changes.
- Agent roles and model tiers: strongest for controller/final review, standard/strongest for cross-system implementation, fast for mechanical parity checks; spawn settings are explicit.
- Work pack: `specs/014-adaptive-v2/work.md`.
- Legacy startup: this R2 created the old trio under v0.13. Architectural + `legacy_startup_evidence: true` preserves it without setting a bounded precedent.

## Method Checkpoints

- TDD policy is `required`: negative fixtures detect invalid shape, stale SHA, contract-digest mismatch, forged text evidence, missing full+governance collection, and artifact-matrix violations; mutate critical fields when applicable to confirm failure.
- Repair: root-controller both rounds, recording round/hypothesis/failure and fix base/head/diff digest; stop before third.
- Review: batch W1/W2/W3, final global, install/evidence specialist; fixes use re_review linked to original batch/scope. Reviewers are independent and findings all zero.
- Parallel boundaries: read-only may parallelize; write batches have disjoint paths; implementers/reviewers do not recursively spawn.

## Blockers

- None

## Closure Evidence

R2 close requires verification profile and atomically creates CR, normal-checks, and cleans. Advisory method warnings leave completeness incomplete. This pack is not closed.

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

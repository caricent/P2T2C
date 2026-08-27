---
artifact: closure_report
schema_version: 3
id: CR-YYYYMMDD-short-title
risk: R2
execution_shape: bounded
change_pack: docs/change_packs/CPK-YYYYMMDD-short-title.md
work_pack: none
gate_a: satisfied
truth_drift: none
decision: CLOSE
verification_policy: machine_bound
final_tree_sha: pending
evidence_digest: pending
evidence_storage: sidecar_jsonl
evidence_ref: pending
evidence_event_count: pending
contract_digest: pending
evidence_trust: local_consistency
review_base_sha: pending
review_head_sha: pending
truth_patch_ref: docs/sot/path.md
truth_patch_digest: pending
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: none
legacy_startup_evidence: false
methodology_enforcement: advisory
evidence_completeness: pending
evidence_warnings: pending
path_mapping_digest: pending
matched_profiles: pending
matched_paths_digest: pending
baseline_sha: pending
remaining_risk_status: none
remaining_risk_ref: none
---

# CR-YYYYMMDD-short-title

## Completion Summary

- Implemented scope:
- Related Truth / ADRs:
- CPK/work drift backfill: None / Backfilled
- Truth Drift: None / Accepted through Gate B and applied as a Truth Patch
- Gate B: when not triggered, status is `not_triggered` and decision/ref are `none`; resolved closure references the `gate_b` event, human decision, and `truth_patch_ref`

## Remaining Risks

- None

## Machine Evidence

Close atomically projects one receipt-v2 line here. Receipt contains Gate A, Truth ref/digest, ownership/legacy, methodology enforcement/completeness/warnings, path mapping, baseline, remaining-risk ref, and sidecar ref/digest/count. Raw events live only under `docs/closure/evidence/**`. Advisory warnings cannot masquerade as complete; `local_consistency` is not a signature. Failure restores target and retains run state.

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

## Closure

Decision: `CLOSE`

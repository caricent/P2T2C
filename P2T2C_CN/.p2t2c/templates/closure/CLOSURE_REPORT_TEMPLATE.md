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

## 完成摘要

- 实现范围：
- 相关 Truth / ADR：
- CPK/work 漂移回填：None / 已回填
- Truth Drift：None / 已通过 Gate B 接受并应用 Truth Patch
- Gate B：未触发时 status 为 `not_triggered`、decision/ref 为 `none`；resolved 时必须引用 `gate_b` 事件、人类决定和 `truth_patch_ref`

## 剩余风险

- None

## 机器证据

本区由 close 原子投射单行 receipt v2。receipt 包含 Gate A、Truth ref/digest、ownership/legacy、methodology enforcement/completeness/warnings、path mapping、baseline、remaining risk ref 和 sidecar ref/digest/count。原始 events 只位于 `docs/closure/evidence/**`。advisory warning 不得冒充 complete；`local_consistency` 不是签名。失败恢复原目标并保留 run state。

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

## 收口

决策：`CLOSE`

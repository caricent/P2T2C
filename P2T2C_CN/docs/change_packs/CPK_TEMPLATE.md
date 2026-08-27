---
artifact: change_pack
schema_version: 3
id: CPK-YYYYMMDD-short-title
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: bounded
production_code_change: false
multi_agent: false
work_pack: none
implementer: agent-id
tdd_policy: required
governance_change: false
specialist_review_required: false
truth_patch_ref: none
truth_patch_digest: none
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: none
legacy_startup_evidence: false
---

# CPK-YYYYMMDD-short-title

## 意图与边界

- 目标：
- 非目标：
- 来源：

## 路由

- 风险等级及理由：
- execution shape 及理由：
- 升级条件：
- 相关 Truth / ADR：

## 验收与实现策略

- 可观察验收结果：
- 最小实现策略：
- 影响范围：
- 验证 profile：fast / impacted / full / governance
- 每个 changed path 的强制 mapping 与 command IDs：

## Truth Patch

R1 写 `Not required`。R2 描述待应用或已应用的 Truth / ADR 变更；`gate_a: pending` 时不得应用。

## 执行与所有权

- 工作批次：
- 文件所有权：
- 隔离与基线：
- Agent 角色与模型档位：
- architectural 工作的 `work_pack`：`specs/{NNN-feature}/work.md`
- 实现者身份（必须与 reviewer 不同）：
- bounded/spike 使用 `ownership_batches: none`；architectural 填写逗号分隔、唯一的 batch ID：
- 只有从旧流程启动的 architectural 工作可使用 `legacy_startup_evidence: true` 并保留 spec/plan/tasks：

## 方法检查点

- 可证伪测试与 RED/GREEN，或豁免及替代证据：
- TDD 策略：`required | exempt | not_applicable`；exempt 必须记录 `tdd_exemption` 事件：
- 修复负责人和两轮上限：
- 审查层级与专项审查：
- architectural 每个 ownership ID 的 batch review；bounded batch_id=none；修复用 re_review 回链原 scope：
- 并行边界：

## Gate B 与 Truth Patch 追踪

- R1 的 `truth_patch_ref` / `truth_patch_digest` 必须为 `none`。R2 必须引用单一实际 `docs/sot/**` 文件，并记录该文件当前 SHA-256；Truth 改动后必须刷新 digest。
- 未触发 Gate B：`gate_b_status: not_triggered`、`gate_b_decision: none`、`gate_b_ref: none`。
- `gate_b_status` 只允许 `not_triggered | resolved`。resolved 时记录结构化 `gate_b` 事件，且非空 decision/ref 必须同时引用人类决定和已应用 Truth Patch。
- `execution_shape: spike` 不得使用 `status: applied` 或执行 close；必须先升级为 bounded/architectural。
- bounded 新工作拒绝 legacy spec/plan/tasks；只有 architectural + `legacy_startup_evidence: true` 是迁移期例外。

## 阻塞项

- None

## Closure Evidence

工作进行中保持本区为空。close 必带 verification profile，并原子投射单行 receipt v2/check/清理；raw events 存入 `docs/closure/evidence/**` sidecar。advisory 方法缺口进入 warnings 且 completeness 不完整；所有 finding 为 0。

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

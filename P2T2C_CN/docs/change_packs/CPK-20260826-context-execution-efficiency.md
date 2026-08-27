---
artifact: change_pack
schema_version: 3
id: CPK-20260826-context-execution-efficiency
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
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
truth_patch_digest: 93c03bd0722bf74fde374bda0cf55e5f2d8a2b0ac3e0e3b7655612f58bdeb408
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3
legacy_startup_evidence: false
---

# CPK-20260826-context-execution-efficiency

## 意图与边界

- 实施 0.14.1-A 与 0.14.1-B：在保持产出质量、Truth 权威、Gate A/B、审查角色、两轮修复和 final-tree 证据不变的前提下，减少热上下文与重复执行。
- 保持 `methodology.profile: p2t2c-adaptive-v2`；只用发行、能力和 receipt 版本标识引擎变化。
- 明确非目标：0.14.1-C。不新增 Agent 派生阈值、模型/推理档路由、review capsule、compaction 策略或弱化审查语义。
- 用户已给出完整边界，因此 Gate A satisfied。

## 路由与验收

- R2 / architectural：治理 Truth、证据存储、checker/close、安装升级、双语发行面和验证编排共同改变。
- 上下文验收：确定性的 `context`、`status`、`evidence summary` JSON，三个阶段 Skill；默认固定上下文至少比 0.14 降低 50%，热视图不含原始 intent/event/output。
- 证据验收：新 close 写 receipt v2 与内容寻址 sidecar；目标中的 proof 小于 3 KiB；历史 inline receipt v1 原样有效。
- 引擎验收：单进程 checker 索引、安全历史缓存、coverage-aware batch verify、一次 close 语义 prepare、冷失败日志、分 suite/并行 smoke，且不丢失负向 fixture。
- 质量门：同一 tree 上 final full + governance，W1/W2/W3 batch review、最终 global review，以及证据/安装/迁移 specialist review；finding 全部为 0。

## Truth Patch 与所有权

- Truth Patch：`docs/sot/governance/P2T2C_GOVERNANCE.md` 中的 RULE-GOV-017、RULE-GOV-018。
- W1：上下文交付、defaults/manifest、阶段 Skill、兼容 Prompt、本地化文档与 schema。
- W2：evidence/checker/run/verify/close 引擎、sidecar 与 cache 安全。
- W3：smoke suites、真实 0.14.0 fixture、安装升级、版本、checksum 与发行说明。
- 单一集成 controller：`root-controller`；写所有权不得重叠。

## 方法检查点

- TDD 先证明新 wire 缺失，再覆盖 sidecar substitution、stale cache、coverage forgery、事务回滚、有界输出和历史兼容。
- 只读探索可并行；implementer/reviewer 不递归 fan-out。
- 只有接受实现漂移并修改 Truth 才触发 Gate B；当前没有该提议。

## 阻塞项

- None。由于 Git 历史尚无 0.14.0 commit，已在本 Truth Patch 之前冻结字节精确的 0.14.0 发行 fixture。

## 收口证据

等待实现、独立审查、最终验证和 R2 自动收口。

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

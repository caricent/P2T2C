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
truth_patch_digest: 1c3b2bc2666b1acb6846c1c243880890d94c0e00c78c0cc69e40b48058219f92
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3
legacy_startup_evidence: true
---

# CPK-20260826-adaptive-v2

## 意图与边界

- 目标：在保持 AI 产出质量、Truth 权威和 R2 人类控制的前提下，以分层自治、缩放产物和机器证据提升 P2T2C 生产效率。
- 非目标：捆绑 Superpowers、让 spec/CPK 覆盖 SoT、取消最终新鲜验证、把危险或未决定语义交给 Agent，或改写历史 013 制品。
- 来源：2026-08-26 用户明确要求实施的 v0.14 方案；完整语义已给定，因此 Gate A satisfied。

## 路由

- 风险等级及理由：R2；治理 Truth、Gate B、产物契约、证据 schema、安装升级与 Agent 权限边界改变。
- execution shape 及理由：architectural；跨双语发行根、checker/close、安装升级、配置和行为 eval，需多批次所有权与最终集成。
- 升级条件：已处于最高 shape；发现未决定的安全/权限/数据语义时停线回 Gate A。
- 相关 Truth / ADR：RULE-GOV-001、003、014、015、016；ADR-014。

## 验收与实现策略

- 待真实 A/B 验证的目标：bounded R1 手写持久产物从五份降为一份；90% 以上 R0 零手写文档；流程文档量下降至少 60%，总周期下降至少 30%。当前不宣称已达标。
- 待验证的质量非劣门槛：缺陷逃逸、返工和 Truth Drift 不高于 v0.13 control；适用验证和必需审查 100% 绑定最终 diff/tree。
- 以 v0.13 control 对比 adaptive-v2 treatment 的确定性 fixture 与真实 Agent 行为场景；本次只定义 eval，不伪称已经运行真实 LLM eval。
- 验证：每个 changed path 强制 mapping；同一 final tree 的完整 full + governance；CLI 只用配置 profile+command ID。

## Truth Patch

已准备并将在本 R2 批次集成时原子应用：

- 五治理状态合并为三个 runtime 循环。
- 新增风险 × execution shape 双轴路由与单调升级。
- 应用 R0/ bounded R1 / architectural / R2 产物矩阵和缩窄 Gate B。
- 应用 CPK/CR v3、contract digest/local-consistency receipt、验证 profile 与单一 `.p2t2c/managed-files.txt` 清单。
- 应用 adaptive review、并行、fan-out、模型档位、事件等待和两轮 scoped repair 边界。

## 执行与所有权

- ownership batches：W1 治理/双语文档与上游事实；W2 机器证据/checker；W3 安装升级/managed-files/config。ID 唯一且每批次必须有 batch review。
- 文件所有权：W1-W3 独占；最终集成不创建第四 ownership batch，由单一 controller 合并并触发 global/specialist 与 full/governance。
- 隔离与基线：宿主管理的共享工作区，分配不重叠路径；保留用户既有改动。
- Agent 角色与模型档位：controller 与最终审查使用最强档；跨系统实现使用标准/最强档；机械一致性检查使用快速档；spawn 显式设置。
- work pack：`specs/014-adaptive-v2/work.md`。
- legacy startup：本 R2 在 v0.13 下先创建旧三件套，因当前为 architectural 且 `legacy_startup_evidence: true` 可保留；不作为 bounded 先例。

## 方法检查点

- TDD 策略为 `required`：负向 fixture 必须能检出非法 shape、陈旧 SHA、契约摘要不一致、伪造文本证据、缺失 full+governance 集合和产物矩阵违规；适用时 mutation 修改字段确认测试失败。
- repair：两轮均 root-controller，记录 round/hypothesis/failure、fix base/head/diff digest；第三轮停线。
- 审查：W1/W2/W3 各 batch，final global，安装/证据 specialist；修复用 re_review 回链原 batch/scope。reviewer 独立且 finding 全 0。
- 并行边界：read-only 可并行；写批次路径不重叠，implementer/reviewer 不递归派生。

## 阻塞项

- None

## Closure Evidence

R2 close 必带 verification profile，并原子创建 CR、普通 check、清理；advisory 方法 warnings 会使 completeness 不完整。当前尚未收口。

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

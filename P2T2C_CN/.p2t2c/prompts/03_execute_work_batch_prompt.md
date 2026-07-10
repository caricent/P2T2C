# Prompt 03 — 工作批次执行

目标：执行一个目标一致、可整体验收的工作批次。

前置条件：

- R0 已完成风险路由。
- R1/R2 已有合法 `CPK-*`。
- R2 的 `gate_a` 不得为 `pending`。

R1/R2 在 `specs/{NNN-feature}/` 中创建或更新精简三件套：

- `spec.md`：目标、CPK 与 Truth 引用、验收行为。
- `plan.md`：实现策略、影响范围、风险。
- `tasks.md`：批次内相关 Task 与批次级验收命令。

执行规则：

- 一个批次可以包含多个服务同一目标的相关 Task。
- 按代码库既有模式实现，并持续核对 CPK、spec 和 Truth。
- 对可自动化的 R1/R2 行为使用 `skills/risk-aware-tdd/SKILL.md`：依据 Truth/CPK/spec 定义行为，观察聚焦测试失败，实现最小改动，再验证通过。生成产物、纯配置、探索性工作或无法合理自动化时，记录明确豁免及替代证据。
- R2、并行或明确要求隔离的工作之前读取 `skills/workspace-isolation/SKILL.md`。`isolation: auto` 时优先宿主管理的隔离；否则记录当前分支和适用的干净基线。并行仅限任务独立且所有权不重叠的 R2 工作。
- R1 生产代码变更和所有 R2 工作在收口前预留独立双轮审查检查点；不要求逐 Task 提交或逐 Task Actual 记录。
- 不要求逐 Task Actual、`Acceptance scope` 或单 Task 停顿。
- 发现新的语义边界、Truth 冲突、高风险事项或危险操作时，返回意图准入阶段。

完成后报告：批次范围、修改文件、TDD 证据或豁免、隔离/基线状态、准备运行的验证闭集和任何新增风险。

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
- 不要求逐 Task Actual、`Acceptance scope` 或单 Task 停顿。
- 发现新的语义边界、Truth 冲突、高风险事项或危险操作时，返回意图准入阶段。

完成后报告：批次范围、修改文件、准备运行的验证闭集和任何新增风险。

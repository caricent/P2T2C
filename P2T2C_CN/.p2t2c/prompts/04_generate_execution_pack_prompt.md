# Prompt 04 — 生成执行包

目标：基于已确认并应用的 Truth，生成 `spec.md`、`plan.md`、`tasks.md`。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

前置条件：

- 相关 Change Pack 必须已通过 Gate A 并应用。
- 相关 SoT、ADR 必须是当前权威来源。
- 不得从未应用的 proposal 或参考资料生成业务规则。

本阶段额外读取：

- 相关 CP
- 相关 ADR、SoT
- `.p2t2c/templates/execution/spec.md`
- `.p2t2c/templates/execution/plan.md`
- `.p2t2c/templates/execution/tasks.md`

动作：

1. 创建或更新目标 feature 目录下的 `spec.md`。
2. 创建或更新 `plan.md`。
3. 创建或更新 `tasks.md`。
4. 每个执行文档必须引用相关 Truth。
5. task 必须可独立验收，并包含验收命令或步骤。

禁止：

- 不要在 spec、plan、tasks 中新增 Truth 未定义的业务规则。
- 不要用执行文档覆盖 SoT。
- 不要在 tasks 中安排超过已接受 Truth 范围的工作。
- 如果实现需要新表、字段、接口、页面、状态、权限、AI 职责、同步对象或工作流，必须暂停。

完成后报告：

- 生成的 feature 目录。
- 引用的 Truth 和 Rule IDs。
- task 数量和验收方式。
- 是否存在停线项。

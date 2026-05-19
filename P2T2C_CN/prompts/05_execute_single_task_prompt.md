# Prompt 05 — 执行单个任务

目标：一次只执行 `tasks.md` 中的一个 task。

先读取 `AGENTS.md`，并按其中的 Required Reading 完成基础读取。

本阶段额外读取：

- feature `spec.md`
- feature `plan.md`
- feature `tasks.md`
- 相关 SoT、ADR

处理规则：

- 只执行用户指定或 tasks 中下一个未完成 task。
- 编码必须符合 SoT、spec 和 plan。
- 如果发现 plan 假设失效，必须暂停。
- 如果需要 Truth 未定义的新业务规则或边界，必须暂停。
- task 完成前必须运行该 task 的验收命令或步骤。
- 验收失败不得标记完成。
- 完成后填写 Actual results。

禁止：

- 不要顺手执行多个 task。
- 不要重排未授权的 scope。
- 不要通过测试或代码注释引入业务规则。
- 不要静默修改 Truth。

完成后报告：

- 执行的 task ID。
- 修改的文件。
- 验收命令与结果。
- tasks.md 中的 Actual results 更新。

# Prompt 05 — 漂移检查与收口

目标：核对实现与 Truth 的一致性，并为所有完成的 R0/R1/R2 工作生成 `CR-*`。

读取：

- 当前代码变更与验证结果
- 相关 Truth、ADR
- R1/R2 的 CPK 和 `specs/{feature}/` 执行文档
- `.p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md`

动作：

1. 对比代码、CPK、执行文档、Truth 和 ADR。
2. 发现 Execution Doc Drift 时由 AI 自动回填执行文档。
3. 发现 Truth Drift 时触发 Gate B，不得静默更新 Truth。
4. 使用 Closure 模板创建 `docs/closure/CR-YYYYMMDD-short-title.md`。
5. CR 必须记录风险等级、实际验证命令、结果、Truth Drift 状态和剩余风险。

Gate B 选项：

1. 修正实现，使其符合 Truth。
2. 接受实现并更新 Truth。
3. 创建或更新意图、SP、ADR 后重新评估。

正常收口决策统一为 `CLOSE`。

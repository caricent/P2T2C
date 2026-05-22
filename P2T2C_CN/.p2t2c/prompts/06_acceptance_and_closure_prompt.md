# Prompt 06 — 验收与收口

目标：验证实现是否符合 Truth 和执行文档，并生成 Closure Report。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

治理阅读（RULE-GOV-012）：本阶段 phase token 为 `acceptance`。只读取 `.p2t2c/generated/phase_rules.txt` 中 `acceptance:` 行列出的治理 Rule Block，不通读 `P2T2C_GOVERNANCE.md` 全文。仅当 Truth Drift 需要核对 lifecycle 时才读 `P2T2C_GOVERNANCE_HISTORY.md`。

本阶段额外读取：

- feature `spec.md`
- feature `plan.md`
- feature `tasks.md`
- 相关项目 SoT、ADR
- 当前代码变更
- `.p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md`

动作：

1. 运行 feature-level build、test、lint、governance check。
2. 核对所有 task 的 Actual results。
3. 对比 code 与 spec、plan、tasks。
4. 对比 code 与 SoT、ADR。
5. 填写 Closure Report。

Closure Decision 只能是：

- `CLOSE`
- `BACKFILL_EXECUTION_DOCS`
- `HUMAN_TRUTH_DECISION_REQUIRED`

处理规则：

- 如果 build、test、lint 或 governance check 失败，暂停并报告证据，不进入 Closure。
- 如果只是 Execution Doc Drift，可以回填 spec、plan、tasks。
- 如果代码领先、改变、扩展或违反 SoT、ADR，必须标记 Truth Drift，并触发 Gate B。
- 不要静默更新 Truth。

完成后报告：

- 验收命令和结果。
- Closure Decision。
- 是否需要 Gate B。
- Closure Report 路径。

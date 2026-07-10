# Prompt 02 — 风险路由与 Truth

目标：将已准入意图路由为 `R0`、`R1` 或 `R2`，并只在需要时创建 CPK 或触发 Gate A。

风险定义：

- `R0`：重构、测试、文档、CI 调整，或恢复 Truth 已明确定义的行为；不创建 CPK 或执行文档。
- `R1`：实现现有 Truth 已覆盖的行为；创建紧凑 `docs/change_packs/CPK-*.md`，不得修改 Truth。
- `R2`：修改 Truth、ADR、外部契约、持久数据语义、安全、隐私、权限或不可逆操作；创建完整 CPK。

动作：

1. 选择风险等级并记录理由。
2. R1/R2 使用 `docs/change_packs/CPK_TEMPLATE.md` 创建 CPK。
3. 项目启用方法配置时，将其复制到新 CPK 并识别适用的方法检查点。该选择不得改变风险等级、Truth 边界或 Gate A/B 要求。
4. R2 判断当前用户指令是否已经明确决定完整语义：
   - 已明确决定：`gate_a: satisfied`，无需重复批准。
   - 尚未决定：`gate_a: pending`，暂停并提供明确选项。
5. Gate A 满足后才可应用 R2 Truth Patch；应用后将 CPK 标记为 `status: applied`。
6. R1 必须使用 `truth_change: false`、`gate_a: not_required`。

禁止：

- R0 创建无必要的流程文档。
- R1 修改 Truth 或 ADR。
- `gate_a: pending` 的 R2 应用 Truth Patch或进入执行阶段。
- 用 CPK、spec、测试或代码替代 Truth。

输出：风险等级、CPK 路径（如有）、Gate A 状态和下一阶段入口。

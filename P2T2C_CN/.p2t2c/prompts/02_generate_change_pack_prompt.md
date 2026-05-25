# Prompt 02 — 生成 Change Pack（不改文件）

目标：根据 Submit Proposal 生成 Change Pack。如果 SP 不需要变更 SoT 或 ADR，走 Fast Path 并直接生成 CPK；如果需要变更 SoT 或 ADR，在 CPK 中用明确 Gate A 选项让人类决策。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

治理阅读（RULE-GOV-012）：本阶段 phase token 为 `change_pack`。只读取 `.p2t2c/generated/phase_rules.txt` 中 `change_pack:` 行列出的治理 Rule Block，不通读 `P2T2C_GOVERNANCE.md` 全文，也不读 `P2T2C_GOVERNANCE_HISTORY.md`。

本阶段额外读取：

- 当前 SP 文件
- 与 SP 相关的项目 SoT、ADR
- `.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`

输出 Change Pack，必须包含：

1. Admission Summary
2. Impact Review
3. Change Pack Body
4. Gate A 决策选项和所需人类动作

处理规则：

- 必须先填写 `Admission Summary`，判断 Proposal 是否可以进入 Truth。
- 必须明确判断是否需要 SoT 或 ADR 变更，并填写对应路由字段。
- Admission decision 只能是：`READY`、`NEEDS_PROPOSAL_REPAIR`、`CONFLICTS_WITH_TRUTH`、`CONFLICTS_WITH_IMPLEMENTED_TRUTH`、`ADR_REQUIRED`、`OUT_OF_SCOPE`。
- 如果 decision 是 `READY` 且不需要 SoT 或 ADR 变更，走 Fast Path，写 `Truth Patch Candidate: Not required`，设置 `Gate A required: No`，并直接生成 CPK。
- 如果 decision 是 `READY` 且需要 SoT 或 ADR 变更，生成 Truth Patch Candidate 并设置 `Gate A required: Yes`；在修改任何 Truth 或 ADR 文件前，必须让人类选择 Gate A 选项。
- 如果 decision 不是 `READY`，禁止生成可应用 Truth Patch Candidate；必须写 `Truth Patch Candidate: Not generated`，并只输出一个统一 `Blocking Brief`。
- 阻塞时不要同时展开多套 Repair、Conflict、ADR 模板。
- 人类问题必须是可决策选项，最多列出 5 个高影响问题。
- 如需要 Gate A，必须让人类从一组明确选项中选择一项。界面支持选项选择时直接使用选项；否则列出选项并等待人类选择。

禁止：

- 不要修改文件。
- 不要生成代码。
- 不要自行接受 ADR。
- 不要把业务规则写进 Agent rules、prompt、tests 或 code comments。

如 Stop-the-line Checklist 任一项为 Yes，Admission decision 不得为 `READY`。

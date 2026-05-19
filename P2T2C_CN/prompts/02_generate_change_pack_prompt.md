# Prompt 02 — 生成 Change Pack（不改文件）

目标：根据 Change Proposal 生成 Change Pack，供 Gate A 人工确认。

先读取 `AGENTS.md`，并按其中的 Required Reading 完成基础读取。

本阶段额外读取：

- 当前 CP 文件
- 与 CP 相关的 SoT、ADR
- `templates/change_pack/CHANGE_PACK_TEMPLATE.md`

输出 Change Pack，必须包含：

1. Admission Summary
2. Impact Review
3. Change Pack Body
4. Gate A 所需的人类动作

处理规则：

- 必须先填写 `Admission Summary`，判断 Proposal 是否可以进入 Truth。
- Admission decision 只能是：`READY`、`NEEDS_PROPOSAL_REPAIR`、`CONFLICTS_WITH_TRUTH`、`CONFLICTS_WITH_IMPLEMENTED_TRUTH`、`ADR_REQUIRED`、`OUT_OF_SCOPE`。
- 如果 decision 是 `READY`，走 Fast Path，生成 Truth Patch Candidate 和 Execution Pack Summary。
- 如果 decision 不是 `READY`，禁止生成可应用 Truth Patch Candidate；必须写 `Truth Patch Candidate: Not generated`，并只输出一个统一 `Blocking Brief`。
- 阻塞时不要同时展开多套 Repair、Conflict、ADR 模板。
- 人类问题必须是可决策选项，最多列出 5 个高影响问题。

禁止：

- 不要修改文件。
- 不要生成代码。
- 不要自行接受 ADR。
- 不要把业务规则写进 Agent rules、prompt、tests 或 code comments。

如 Stop-the-line Checklist 任一项为 Yes，Admission decision 不得为 `READY`。

# Prompt 03 — 应用已确认的 Change Pack

仅在 Gate A 已由人类确认后使用。

前置条件：

- Change Pack 的 `Admission decision` 必须是 `READY`。
- Gate A 必须明确选择 `Approve and apply Truth Patch`。
- Change Pack 不得包含未解决的 `Blocking Brief`。
- 如存在 `Truth Patch Candidate: Not generated`，必须暂停，不能应用 SoT 或 ADR 变更。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

治理阅读（RULE-GOV-012）：本阶段 phase token 为 `apply_change_pack`。只读取 `.p2t2c/generated/phase_rules.txt` 中 `apply_change_pack:` 行列出的治理 Rule Block，不通读 `P2T2C_GOVERNANCE.md` 全文。仅当排查 lifecycle 冲突时才读 `P2T2C_GOVERNANCE_HISTORY.md`。

本阶段额外读取：

- 已确认的 Change Pack
- 相关 SP、项目 SoT、ADR
- `.p2t2c/templates/truth/SOT_DOCUMENT_TEMPLATE.md`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`
- `docs/sot/manifest.yaml`

动作：

1. 应用 Truth Patch 到 `docs/sot/`。
2. 如 Change Pack 包含 ADR 动作，只有在 Gate A 已明确确认完整 ADR 内容且没有阻塞项时才创建或更新 `docs/adr/`；否则暂停。不包含 ADR 动作时跳过。
3. 更新 `docs/sot/manifest.yaml`。
4. 运行 `make check`。

禁止：

- 不要把业务规则写入 `P2T2C_AGENTS.md`、项目自有 `AGENTS.md`、prompt、tests 或 code comments。
- 不要让 prompt、tests、spec 单独定义新规则。
- 如果应用过程中发现新冲突，立即暂停。
- 如果 Change Pack 包含 `Blocking Brief`，必须暂停并要求人类先解决阻塞项。
- 如果 `make check` 失败，必须暂停并报告失败证据。

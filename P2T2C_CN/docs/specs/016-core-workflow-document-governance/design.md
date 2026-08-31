---
artifact: design
schema_version: 1
proposal: docs/proposals/SP-20260831-core-workflow-document-governance.md
status: ready
---

# 技术设计

## 上下文引用

- SP-20260831-core-workflow-document-governance。
- P2T2C Governance RULE-GOV-001 至 020。
- Fission-AI/OpenSpec 的动作与 schema 设计。

## 技术决策

- 新工作使用 SP + design.md + tasks.md；SOT 直接承担行为契约。
- 新 Archive 使用独立 Documents 模块，不扩展 legacy evidence 引擎。
- legacy CPK/run 继续原 context/evidence/verify/close。
- docs-migrate 是显式冷路径，使用 decision map、锁、备份和报告。
- completed specs 原地保留，冷归档只保存旧格式。

## 接口与数据流

- AI Propose 写 SP/design/tasks。
- Apply 只调用项目工程工具。
- p2t2c archive --spec ID 校验三文档与 SOT 后更新 tasks。
- p2t2c docs-migrate 提供 dry-run/apply/rollback。

## 数据或迁移设计

- submit_proposals 的 SP 逐叶移动至 docs/proposals。
- 根 specs、ADR、CPK、CR/evidence 原字节移动至 reference/archive。
- 活动引用使用冻结映射重写，ADR 映射必须指向现存 DEC anchor。

## 风险与权衡

- 不自动迁移可避免 upgrade 修改项目文档，但需要一次显式操作。
- 旧项目在迁移前同时保留 legacy 与 core 工具。
- Verify 可选降低流程成本，已知失败仍硬阻断 Archive。

## 未决问题

- None。

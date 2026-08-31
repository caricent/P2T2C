---
artifact: implementation_tasks
schema_version: 1
proposal: docs/proposals/SP-20260831-core-workflow-document-governance.md
design: docs/specs/016-core-workflow-document-governance/design.md
status: completed
---

# 实施任务

## 任务

- [x] 1.1 撤回未发布的 assurance/Flow/event-v2/receipt-v3 候选
- [x] 1.2 定义核心动作、三域文档与 SOT Decision Records
- [x] 2.1 实现 Documents validator 与轻量 Archive
- [x] 2.2 实现显式 docs-migrate dry-run/apply/rollback
- [x] 3.1 更新 installer、upgrader、manifest、inventory 与双语入口
- [x] 3.2 更新 parity、core/migration/security/transaction smoke
- [x] 4.1 完成独立审查与 legacy full/governance 验证
- [x] 4.2 收口当前 legacy CPK 后执行并验证文档布局迁移

## 完成记录

- Tests: passed
- Verify: clear
- Known blockers: none
- Dangerous operations: none
- Authorization ref: none
- Summary: 0.15 核心动作、三域文档、轻量 Archive、legacy 兼容与双语显式迁移已完成；发行验证和迁移后完整性检查通过。

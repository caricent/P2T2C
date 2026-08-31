---
artifact: proposal
schema_version: 1
id: SP-20260831-core-workflow-document-governance
status: approved
risk: R2
decision: approved
decision_ref: user_instruction
specs_ref: docs/specs/016-core-workflow-document-governance
truth_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_digest: 9495632de31553655fe853dbfdfa29ded9f49b3163a391f7a88b2c26aa6d0eae
---

# SP-20260831-core-workflow-document-governance

## 为什么

- 0.14.1 与早期 0.15 候选把大量注意力放在证明、验收和流程制品上，小任务耗时不可接受。
- 采用 OpenSpec 式动作工作流，并复用 P2T2C 自身 SOT，减少默认文档和运行控制面。

## 变更内容

- 默认动作改为 Explore、Propose、Apply、可选 Verify、Archive。
- 活动文档改为 proposals、specs 和 SOT。
- 新变更只使用 SP、design.md、tasks.md。
- ADR 决策进入 SOT，旧制品进入冷归档。
- 普通升级不迁移文档；提供显式可回滚 docs-migrate。
- Archive 不运行测试、review、CI 或 release smoke。

## 非目标

- 不替代项目测试、CI、code review 或发布体系。
- 不改写历史 CPK、CR、ADR 或 legacy specs 内容。
- 不迁移仍有活动 CPK/run 的项目。

## 可观察结果

- 清晰 R1 从用户指令直接进入 Propose/Apply，不增加确认。
- 每个新 specs 目录只有 design.md 与 tasks.md。
- Archive 只更新 tasks status。
- 0.14.x 活动工作升级后仍可按原流程收口。
- 文档迁移 dry-run 零写，apply/rollback byte-exact。

## Truth 影响

- 更新 P2T2C Governance 的核心动作、文档矩阵、Decision Record、质量边界与迁移规则。

## 决策

- 用户已明确批准完整方案，decision 为 approved。

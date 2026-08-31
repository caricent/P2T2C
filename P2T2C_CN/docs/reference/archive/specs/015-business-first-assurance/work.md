---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260831-business-first-assurance.md
---

# Work 015：核心工作流与文档治理

## 接口与数据流

- Propose：用户指令 -> SP -> design.md -> tasks.md。
- Apply：SP/SOT -> 业务实现与项目原生检查；实现学习回写 SP/design。
- Archive：只读取 proposal/design/tasks/SOT，检查已知阻断，原子更新 tasks status。
- docs-migrate：显式 decision map -> byte-exact 冷归档 + 活动引用重写 + 可回滚报告。
- Legacy：已有 CPK/run 继续 context/status/evidence/verify/close。

## 任务 DAG 与独占范围

| ID | 范围 | 前置 | 验收 |
|---|---|---|---|
| W1 | Truth、DEC、核心模板/schema | Gate A | 三文档职责清晰，旧 ADR 决策 disposition 明确 |
| W2 | Documents、Archive、CLI | W1 | 完成门槛正确且不执行项目命令 |
| W3 | docs-migrate、install/upgrade、事务安全 | W1/W2 | dry-run 零写、apply/rollback byte-exact、活动 run 拒绝 |
| W4 | manifest/inventory、README、parity/smoke | W1-W3 | 双语和冻结升级 fixture 全绿 |

## 验证、审查与恢复

1. 聚焦 fixture 覆盖 R0、R1、R2 pending/approved、Archive 阻断和无测试编排。
2. migration/security/transaction suite 覆盖冲突、symlink/hardlink、失败恢复与 rollback。
3. W1-W4、global、compatibility specialist 独立审查均为零 finding。
4. 当前 legacy work 最终运行 full + governance 和 release smoke all 后收口；再显式迁移文档布局。

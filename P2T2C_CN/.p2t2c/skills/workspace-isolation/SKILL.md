---
name: p2t2c-workspace-isolation
description: 为 P2T2C 写工作和多 Agent 集成建立与风险相称的隔离、所有权和恢复边界。
---

# 工作区隔离

先检测宿主提供的隔离并优先复用。`isolation: auto` 只在 R2、写并行或用户明确要求时创建/请求 worktree；其他工作记录当前分支、base SHA 和适用基线，并写入携带 contract digest 的 `isolation` 事件。

- read-only 探索可以全面并行。
- architectural 写并行必须使用 CPK 中唯一 batch IDs，文件不重叠、基线明确、单一 controller 集成；每个 ID 都有 batch review。
- 同形微任务共享验收面时合并 dispatch；紧耦合文件归同一 ownership batch。
- 只有 controller 可以派生 Agent；implementer/reviewer 不得递归 fan-out。
- 交接使用 CPK/work 指针、提取后的 brief、base/head diff 和 ledger 路径，避免复制完整聊天。
- 删除 worktree 前检查未跟踪与未提交内容；存在内容时停线并列明路径，不得强删。

隔离只保护实现状态，不能替代 Gate A/B、Truth、危险操作确认、独立审查或 final-tree full 验证。

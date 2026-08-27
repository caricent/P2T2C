---
name: p2t2c-admit-route
description: 以最小确定上下文完成意图准入、Truth 检索、风险×execution shape 路由和 Gate A。
---

# 准入与路由

## 输入

1. 运行 `p2t2c context --phase admit-route --intent-file - --json`；不把原始意图写入胶囊。
2. 读取胶囊指向的精确 Truth/ADR、相关代码和测试。出现 `UNINDEXED_PROJECT_TRUTH` 时，先按 intent 检索 `docs/sot/**/*.md`（排除 History）再路由。胶囊 hint 不是 route 或 Truth。

## 输出

- 可验收目标/非目标、权限边界、Truth ref+digest、`R0|R1|R2` 与 `spike|bounded|architectural`。
- 按产物矩阵创建/更新 CPK v3 和适用 work；首个机器事件为 `route`。
- 已完整决定的 R2 记 `gate_a: satisfied`；真正未决才 pending。

## 停线

仅在未决 R2 语义、Truth 冲突、危险/不可逆/外部副作用或权限缺失时停线。Gate A pending 只记安全只读 exploration。需深度澄清时按需读 `design-refinement`，不加载其他阶段 Skill。

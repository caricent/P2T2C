---
name: p2t2c-execute
description: 从 CPK/work 与当前 status 恢复，按 Truth、所有权和风险感知 TDD 执行工作。
---

# 计划与执行

## 输入

1. 运行 `p2t2c context --phase execute --work-id <id> --json` 和 `p2t2c status --work-id <id> --json`。
2. 读取胶囊列出的 Truth、CPK 和适用 work；默认不读 raw ledger/CR/sidecar。

## 输出

- 在 CPK 契约和 Gate A 允许的边界内完成实现，按 `tdd_policy` 记录 RED/GREEN 或豁免。
- architectural 工作遵守唯一 ownership batch；保留用户改动、基线与单一集成 controller。
- 失败时按日志 ref 读取必要 cold output，诊断根因；不为调试加载全部历史。

## 停线

新语义、风险/shape 升级返回 `admit-route`。需 TDD、根因或隔离细则时，只按需读对应专业 Skill。不改变 Agent 派生、模型、审查或两轮修复规则。

---
name: p2t2c-risk-aware-tdd
description: 对可自动化的 P2T2C R1/R2 行为使用可证伪、绑定 tree 的测试先行开发。
---

# 风险感知 TDD

1. 从 Truth、CPK 和验收行为定义最小测试，并先写清哪一种生产缺陷会令它失败。
2. 期望值不得由被测生产逻辑推导；测试必须在错误实现下有真实失败能力。
3. `tdd_policy: required` 时，通过 run recorder 观察 RED，再实现最小改动并记录 GREEN；两者绑定 tree SHA 与当前 `contract_digest`。
4. 对生成器、checker、prompt 或 skill，优先测试消费者行为而非只 grep 文本存在；适用时临时 mutation 关键条件，确认测试会失败，再恢复 mutation。
5. 完成聚焦验证后运行由 diff/profile 要求的批次验证。

合规豁免使用 `tdd_policy: exempt` 和 `tdd_exemption` 事件，说明原因及替代命令/结果；只有确实没有可测试行为时使用 `not_applicable`。spike 仍不得 close。不得从测试推断新业务行为；冲突时返回准入与路由。

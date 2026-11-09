# P2T2C_AGENTS.md — AI 入口

P2T2C 0.16 服务于一个人与 AI 又快又好地交付：明确目标，连续推进，检查结果，简短收口。当前规则只由 docs/sot/** 定义；按影响读取完整适用条款及依赖，不默认整篇读取或每步重读。

## 开始与继续

- R0 不建流程制品；用户要求的报告或方案仍可交付，不因此获得实施授权。
- 先定位当前工作。已有 standard、compact 或 legacy 沿用原身份；历史目录里存在 CPK 不代表新工作走 legacy。
- 由模型选择记录形态：接入支持时，简单明确的 R1 优先 compact v2，只保留 SP；其他工作沿用 standard v1 的 SP + design.md + tasks.md。不让用户选模板。
- 清晰 R1 和用户已明确决定的 R2 不重复确认。R2 未决停线；决定明确后先更新 SOT 与必要 DEC，再做受影响实现。
- 模型选择检索、拆解、实现、调试与检查方法。普通失败在授权内继续修复，不逐步骤审批。检查与改动影响相称，复用仍有效的结果；不每步全量回归、不为低影响文字修改补造测试。
- compact 在 SP、standard 在 tasks 记录实际结果、检查范围、来源、未验证部分和必要接续。无需六列表格或独立交接文件。

## 停止动作与完成

- 代码违背明确 SOT：按 R1 修复。新业务语义、有效规则冲突：解决必要决定。绑定变化：比较影响后处理，不盲刷 digest。
- 停止未授权危险动作、覆盖用户修改、依赖缺失环境的动作；已有授权在动作、对象和范围不变时有效。
- 已知失败、未解决 Critical、未完成义务或必要验收失效阻断完成；必要验收缺口写 Known blockers: present。
- 无阻塞后运行一次 `.p2t2c/bin/p2t2c archive --proposal SP-... --json`；已有 standard 可继续 `archive --spec NNN-name --json`。项目有包装入口时使用它。无需先依次跑结构、就绪和全仓校验；归档复用内部检查，不重跑项目测试。

## 按需入口

- 当前 SP 位于 docs/proposals/；standard 的设计与任务位于 docs/specs/。
- 文档字段与命令示例：P2T2C_README.md、.p2t2c/templates/core/。
- 完整治理：docs/sot/governance/P2T2C_GOVERNANCE.md。
- 仅当前工作确有既存 CPK/run 时，使用原 legacy context/status/evidence/verify/close。配置和证据不转换。
- 冷归档、原始 legacy 日志和迁移记录只在对应恢复、冲突或审计时读取。

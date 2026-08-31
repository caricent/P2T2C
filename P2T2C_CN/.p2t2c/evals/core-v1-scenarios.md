# Core v1 场景

| ID | 场景 | 期望 |
|---|---|---|
| C-R0 | 只读探索 | 不创建文档 |
| C-R1 | 明确 R1 | 生成 approved SP、ready design、tasks；无需额外确认 |
| C-R2P | 未决 R2 | decision pending，禁止 Apply/Archive |
| C-R2A | 明确 R2 | 更新 SOT、绑定 digest 后 Apply |
| C-V | 未运行 Verify | 如实记录 not_run，允许 Archive |
| C-B | 已知失败 | failed/critical/blocker/pending 任一阻断 Archive |
| C-A | 正常 Archive | 只更新 tasks status，不执行项目命令或生成证据 |
| C-M | 文档迁移 | dry-run 零写，apply/rollback byte-exact |

真实 Agent A/B 另行评估非业务注意力、首次业务编辑与端到端周期；确定性 fixture 不代替真实评估。

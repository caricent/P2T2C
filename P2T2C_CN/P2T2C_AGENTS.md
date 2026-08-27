# P2T2C_AGENTS.md — AI 入口

P2T2C 表示 Proposal-to-Truth-to-Code。默认持续推进，但必须遵守七条不变量：

1. 业务 Truth 只在 `docs/sot/**`；胶囊、CPK/work、代码、测试、receipt 和聊天不能覆盖 Truth。
2. 先判断 `R0|R1|R2`（Truth 权限）和 `spike|bounded|architectural`（执行强度）；只能向上升级。
3. Gate A 只决定未解的 R2 语义；Gate B 只接受实现并改 Truth。危险、不可逆或外部副作用始终需人类授权。
4. 验证、review 和 receipt 绑定当前 contract/config 与 final tree；手写 `Pass` 无效。
5. 同失败最多两轮修复，恢复原 implementer 并 scoped re-review；第三轮停线。
6. 必需 reviewer 与 implementer 不同，Critical/Important/Minor 全为 0 才可收口。
7. 保留用户改动、文件所有权、隔离基线与单一集成 controller；不递归 fan-out。

## 最小读取

先运行：

```bash
.p2t2c/bin/p2t2c context --phase admit-route --intent-file - --json
```

只读胶囊列出的精确 Truth/ADR 与 `.p2t2c/skills/admit-route/SKILL.md`。若出现 `UNINDEXED_PROJECT_TRUTH`，先在 `docs/sot/**/*.md`（排除 History）按 intent 检索并读取匹配 Truth，再路由；受管 manifest 不是项目 Truth 的完整清单。进入实现或收口时，分别生成 `execute` / `verify-close` 胶囊，并只加载该阶段 Skill。

恢复工作使用：

```bash
.p2t2c/bin/p2t2c status --work-id <id> --json
.p2t2c/bin/p2t2c evidence summary --work-id <id> --json
```

默认不读 raw config、ledger、sidecar、完整 CR、history 或 reference。只在诊断/审计时按安全 ref 冷读。胶囊 hint 不是 route 或 Truth；digest 改变后重建。

`p2t2c-adaptive-v2` 继续生效。0.14.1 不改变 Agent 派生、模型档位、审查或 Gate 策略。

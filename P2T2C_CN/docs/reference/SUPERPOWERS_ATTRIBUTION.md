# Superpowers 方法来源说明

P2T2C 0.13.0 的原生方法层以 [obra/superpowers](https://github.com/obra/superpowers) `v6.1.1` 为上游参考基线（审阅日期 2026-07-10）。截至 2026-08-26，调研到的最新正式版为 [`v6.3.0`](https://github.com/obra/superpowers/releases/tag/v6.3.0)，v0.14 评估了 [`v6.2.0`](https://github.com/obra/superpowers/releases/tag/v6.2.0) 与 v6.3.0 的增量。

## 有机吸收

来自 v6.2 的方法启发：

- 按计划/工作隔离的临时 ledger，持久结论回到 Git 与收口产物。
- 两轮修复恢复原 implementer，修复后只 scoped re-review finding 与 fix diff。
- 用可证伪测试、独立预期和适用 mutation check 验证真实行为，而不是只 grep prompt/skill 文本。
- 压缩重复方法说明，把硬约束放在行为触发点。

来自 v6.3 的方法启发：

- `spike / bounded / architectural` 分档，并让产物仪式随工作强度缩放。
- 同形微任务合并 dispatch/review，reviewer 仍逐项核对 brief。
- 只有 controller 可以派生 Agent，implementer/reviewer 禁止递归 fan-out。
- 使用文件式 brief/diff/evidence 交接、事件驱动有界等待和显式模型/推理档位。
- reviewer 可读取同 tree 的既有机器证据；worktree 含未跟踪/未提交内容时不强删。

以上是方法转译，不复制上游 runtime。上游 release/PR 中的效率和 eval 数字是项目方自报，P2T2C 不把它们当作自身效果证明；`.p2t2c/evals/adaptive-v2-scenarios.md` 定义了独立 A/B 场景，只有真实运行后才报告结果。

v0.14 因此只以 adaptive-v2 advisory 试运行；没有真实 A/B 达标证据和单独的人类推广决定，不提升 required。机器 receipt 的 `local_consistency` 也仅是本地非对抗一致性，不是上游或远程安全证明。

Truth Patch digest、强制 path mapping、ownership batch IDs、quiet/configured runner、advisory completeness/warnings 与 atomic close 是 P2T2C 自身控制，不应归因于上游 Superpowers。

## 明确保留的 P2T2C 边界

- 不采用所有任务统一人工批准；Gate A 只处理尚未决定的 R2 语义。
- 不让 spec、plan、CPK 或运行 ledger 覆盖 SoT。
- 不采用五轮修复、搁置任何非零 finding、每任务强制 worktree 或每 Task 一个 Agent。
- 非语义、可逆的执行冲突可由 controller 留有理由地处理；业务、架构、安全、权限、数据、危险或外部副作用仍停线。
- reviewer 可以避免在相同 tree 上机械重跑全部 suite，但收口仍必须有绑定最终 tree 的新鲜验证。

P2T2C 不要求、不捆绑、也不执行 Superpowers 插件。上游项目以 MIT License 发布；本说明只提供方法来源与可追溯性，不增加上游运行时依赖。

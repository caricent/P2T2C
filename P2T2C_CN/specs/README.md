# 执行文档

adaptive-v2 只为 `execution_shape: architectural` 创建一份执行文档：

```text
specs/{NNN-feature}/
  work.md
```

`work.md` 必须在 front matter 中引用 CPK v3，并只记录接口/数据流、任务 DAG、文件所有权、集成顺序、验证、审查和恢复点。意图、Truth 引用与验收仍以 CPK 为主；业务规则仍只能位于 `docs/sot/**`。

上下文恢复使用 `p2t2c context --phase execute --work-id <id> --json` 与 `p2t2c status --work-id <id> --json`，不把 raw ledger 复制进 work。

- spike 默认不创建执行文档。
- bounded R1 只创建 CPK v3。
- bounded R2 使用 CPK v3、Truth Patch 和自动 CR，不创建 work。
- architectural R1/R2 创建 CPK v3 + work。

bounded 新工作存在 spec/plan/tasks 即违规。只有 architectural CPK 明确 `legacy_startup_evidence: true` 时可保留真实旧流程启动三件套。014 CPK 正是该迁移例外，不是 adaptive-v2 新产物示例。

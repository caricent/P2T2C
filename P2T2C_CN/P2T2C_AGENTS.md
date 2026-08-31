# P2T2C_AGENTS.md — AI 入口

P2T2C 0.15 的默认核心动作是：

```text
Explore 可选 -> Propose -> Apply -> Verify 可选 -> Archive
```

## 新工作

1. R0 只读探索不创建文档。
2. R1/R2 创建 `docs/proposals/SP-YYYYMMDD-short-title.md`。
3. 在 `docs/specs/<NNN-short-title>/` 创建且只创建 design.md 与 tasks.md。
4. R1 使用现有 SOT；R2 decision pending 时停线，approved 后先更新 SOT。
5. Apply 围绕 SP 可观察结果实现，按项目惯例运行必要测试；不要加载 P2T2C verification profile、ledger、receipt 或冷归档。
6. Verify 可选，只报告 completeness、correctness、coherence。
7. 满足完成条件后运行：

```bash
.p2t2c/bin/p2t2c archive --spec <NNN-short-title> --json
```

Archive 不运行测试、review、CI 或 release smoke。

## 必须停线

- R2 decision pending。
- 实现发现 Truth 漂移。
- 已知失败测试、Verify Critical 或未完成任务。
- 危险操作缺少明确授权。
- 用户已有改动会被覆盖。

## 文档权威

- 当前行为只能由 `docs/sot/**` 定义。
- SP 写 why/what；design 写 how；tasks 写执行与完成。
- Decision rationale 使用 SOT 中的 `DEC-*`。
- `docs/reference/archive/**` 是非权威冷历史，默认禁止读取。

## Legacy 兼容

发现已有 `docs/reference/archive/change_packs/CPK-*.md` 或 `.p2t2c/runs/**` 时，该工作继续使用 0.14.x 的 context/status/evidence/verify/close。不要把 legacy 工作转换成新文档，也不要因 0.15 升级改变其配置或证据。

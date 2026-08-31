---
name: p2t2c-core
description: 使用 Explore、Propose、Apply、可选 Verify 与 Archive 推进 0.15 新工作。
---

# P2T2C Core

- Explore 可选且不创建文档。
- R1/R2 必须创建 docs/proposals/SP-*，并在 docs/specs/<change>/ 创建 design.md 与 tasks.md。
- 清晰 R1 或用户已明确批准的 R2 不重复询问。
- Apply 只围绕 SP 可观察结果工作，按项目惯例运行必要测试；P2T2C 不编排测试或 reviewer。
- 实现发现 Truth 漂移时把 SP decision 改为 pending，并停止固化语义。
- Verify 可选，只报告 completeness、correctness、coherence；未解决 Critical 写入 tasks Completion。
- Archive 只调用 p2t2c archive --spec <NNN-name>，不运行测试、review 或 release smoke。
- docs/reference/archive 是非权威冷历史，不能替代 SOT。
- 旧 CPK/run 继续使用 legacy context/evidence/verify/close。

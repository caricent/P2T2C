# P2T2C 核心工作流

P2T2C 表示 Proposal-to-Truth-to-Code。0.16 面向一个人与 AI 又快又好地交付：明确目标 → AI 连续实现与必要检查 → 简短记录并交付。方法、工具和记录由 AI 选择；已有明确决定不重复确认。

## 日常工作

按目标读取完整适用条款、例外和依赖，不默认整篇或每步重读。普通失败在授权内继续修复；只在缺少关键业务决定或具体操作授权时请用户决定。缺少必要环境则说明缺口，保留接续信息。

检查强度与改动影响相称。已有结果仍有效就复用；相关变化或新失败才复测受影响部分。不每步全量回归，不为低影响文字修改补造测试。必要项目检查仍须完成，已知失败和缺失必要验收不能称为完成。

## 记录由 AI 维护

- 简单明确的 R1，在工具和项目接入支持时优先 compact v2，只保留 docs/proposals/SP-*.md。正文写清目标、实际结果与剩余问题，不要求任务清单或统一验收表。
- 需要独立重要设计的 R1 和所有 R2，继续 standard v1：SP + docs/specs/<NNN-change>/{design.md,tasks.md}。未支持 compact 的项目也沿用 standard。
- R0 不建流程制品。已有 standard 与 legacy 保持身份和格式，活动 compact 可在确有需要时原地扩展。

AI 可用 create 生成机械字段。下面是简单工作的一种用法，不需要用户选模板；省略 --shape 时保留 standard 兼容行为。

```bash
.p2t2c/bin/p2t2c create --id SP-20261109-small-fix --shape compact --risk R1 --json
```

R2 选择 standard 并提供 --truth-ref；初始 pending。已有完整有效决定就记录它，先更新相关 SOT，再实施，不重复申请批准。

## 正常收口只归档一次

AI 如实维护完成记录后，使用项目已有的归档包装入口；没有包装时使用核心命令：

```bash
.p2t2c/bin/p2t2c archive --proposal SP-20261109-small-fix --json
```

已有 standard 也可使用 archive --spec NNN-change --json，二者选一。Archive 自带文档检查，不要求先跑 validate-docs、--ready 或全仓校验；它不重跑项目测试、review、CI 或发行 smoke，不生成额外证据报告。Verify 未运行不自动阻断，必要验收缺口必须记录为 Known blockers: present。

compact 更新 SP.work_status，standard 更新 tasks.status。已完成记录可幂等重试，不因后续 SOT 变化自动重开。工具检查声明和引用，实际正确性仍由本次结果与必要项目检查确认。

## 按需维护能力

validate-docs --proposal 定位当前记录；--ready 用于排查归档受阻；全量 validate-docs 用于仓库维护或明确项目检查。它们不是日常命令链。

需要扩展时，AI 准备同一 SP 身份的 proposal.md、design.md、tasks.md，以及原 SP 的 source.sha256，调用 expand --proposal SP-... --prepared <目录>。也可用 --source-digest 传入摘要。工具保护原进度和用户修改；中断优先重试原命令，必要时 recover --proposal。只扩展活动 compact，新语义仍需明确决定。

项目包装可在检查外部证据后，将主记录摘要通过 archive --record-digest 传入以防并发覆盖。定向校验返回 record_digest 和 source_digest；这些内部信息不要求用户填写，也不证明代码已通过测试。

## SOT 与升级

当前规则只在 docs/sot/**。每项规则定义一处，按需原位修订；进度、历史和一次性授权留在工作记录或历史中。行文与篇幅是建议，不设风格门禁或全库清理要求。

本构建为候选版，compact 的使用取决于项目实际接入支持。长期效率统计和跨设备试点不是日常交付条件；未验证范围如实说明。

普通升级保留项目拥有文件和 legacy 证据，不移动文档。布局迁移按需使用 docs-migrate。受支持降级在替换工具前拒绝不兼容记录，包括 completed compact；不要手改 schema 伪装降级。既有 0.14.x CPK/run 继续原 legacy 流程。

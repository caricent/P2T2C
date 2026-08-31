# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-08-31

权威范围：P2T2C 的 Truth 边界、R0/R1/R2、人类决策、核心动作、活动文档、历史兼容、安装升级与双语发行。

## RULE-GOV-001：动作式核心工作流

Status: Active

规则：

0.15 新工作的默认动作是：

```text
Explore 可选 -> Propose -> Apply -> Verify 可选 -> Archive
```

- Explore 只读且不创建文档。
- Propose 一次创建 SP、design.md 与 tasks.md。
- Apply 实现可观察结果，并按项目工程惯例使用测试、CI 与 code review。
- Verify 只做可选的 completeness、correctness、coherence 检查。
- Archive 只检查已知阻断并原地把 tasks.md 标记 completed。
- 动作可以迭代返回早期文档，不形成不可逆阶段门。

验证：

- 新 R1/R2 绑定 SP、design 和 tasks。
- R0 不产生流程文档。

停线条件：

- 未形成明确变更却进入 Apply。
- 默认路径要求 assurance、proof、receipt 或独立 verify-close 阶段。

## RULE-GOV-002：Truth 与来源边界

Status: Active

规则：

当前行为权威只能位于 `docs/sot/**`。来源优先级为：

1. 当前任务中人类明确确认的决定。
2. 当前 `docs/sot/**`。
3. 已批准 `docs/proposals/SP-*.md`。
4. 当前 design.md 与 tasks.md。
5. 当前代码、测试与 CI。
6. `docs/reference/archive/**`。

SP 定义 why/what；design 定义 how；tasks 记录执行和完成。它们都不能覆盖 SOT。冷归档永远非权威。

验证：

- R1 引用现有 SOT。
- R2 在 Apply 前更新并批准 SOT。

停线条件：

- 低优先级来源与高优先级来源冲突。
- 冷归档被当作当前规则。

## RULE-GOV-003：风险与单一人类决策

Status: Active

规则：

- R0：只读探索，不创建持久变更文档。
- R1：实现现有 SOT，decision 为 not_required。
- R2：修改 SOT、外部契约、持久数据语义或不可逆规则，decision 为 pending 或 approved。

Gate A/B 合并为 `decision: not_required|pending|approved`：

- 用户指令已明确决定完整 R2 语义时可直接 approved，不重复询问。
- pending 时不得 Apply、更新 SOT 或完成。
- 实现发现 Truth 漂移时必须把 SP 改回 pending。
- 危险或外部副作用操作始终需要动作发生前的明确授权。

验证：

- approved R2 绑定当前 SOT 路径与 SHA-256。
- 危险操作授权记录在 tasks Completion。

停线条件：

- pending R2 被实现或完成。
- 未授权危险操作。

## RULE-GOV-004：Rule 与 Decision Record 风格

Status: Active

规则：

- 当前规则使用唯一 `RULE-{AREA}-{NNN}`。
- 决策理由使用所属 SOT 中的唯一 `DEC-*` 记录。
- 当前 SOT 定义有效行为；history 保存背景、替代方案、后果与 supersedes。
- 不再创建活动 `docs/reference/archive/adr/**` 文件。

验证：

- 当前 Rule ID 与 Decision ID 唯一。
- Decision 引用锚点存在。

停线条件：

- 新决定只存在于独立 ADR 或聊天。
- 当前 ID 重复。

## RULE-GOV-006：双单语发行根

Status: Active

规则：

- `P2T2C_EN/` 与 `P2T2C_CN/` 是自包含单语发行根。
- 稳定路径、front matter、状态值、脚本和迁移行为一致。
- 冷归档原文可以保留其历史语言，不参与当前单语检查。

验证：

- 根 `make check`、parity 与 release smoke。

停线条件：

- 双语稳定契约分叉。

## RULE-GOV-007：安装后的活动工作面

Status: Active

规则：

活动文档只位于：

- `docs/proposals/`
- `docs/specs/`
- `docs/sot/`

`docs/reference/archive/` 是冷历史；`.p2t2c/` 保存工具、模板、迁移和 legacy 兼容引擎。新工作不使用根 `docs/reference/archive/specs/`、`docs/reference/archive/change_packs/`、`docs/reference/archive/closure/` 或 `docs/reference/archive/adr/`。

验证：

- fresh-install layout smoke。

停线条件：

- 安装覆盖项目拥有的 SP、design、tasks 或 SOT。

## RULE-GOV-008：根入口

Status: Active

规则：

- `P2T2C_README.md` 是人类入口。
- `P2T2C_AGENTS.md` 是 AI 入口。
- 新安装不创建项目通用根 README、AGENTS 或 Makefile。

验证：

- install smoke。

停线条件：

- 安装覆盖项目根入口。

## RULE-GOV-009：当前 Truth 完整性

Status: Active

规则：

- 非 history SOT 中 Rule ID 与 Decision ID 必须唯一。
- `history.md` 和 `*_HISTORY.md` 不参与当前 Rule 唯一性。
- SOT manifest 绑定当前 Truth digest 与 ID。

验证：

- checker 扫描当前 SOT。

停线条件：

- 当前 Truth 重复、缺失或 digest 漂移。

## RULE-GOV-014：核心动作与 Agent 自治

Status: Active

规则：

- 清晰 R1 或已由用户明确批准的 R2 不重复确认。
- Propose 生成实现所需的最小三文档。
- Apply 围绕 SP 可观察结果工作；学习导致的变化回写 SP/design。
- 项目原生测试、CI 和 PR review 属于项目工程体系，不由 P2T2C 编排。
- 写并行仅在所有权不重叠且存在单一集成 controller 时使用。
- 用户已有改动必须保留。

验证：

- AI 默认不读取 legacy ledger、receipt 或冷归档。
- 普通任务不运行 P2T2C release smoke。

停线条件：

- Agent 自行决定未决 R2。
- 流程机制替代业务实现。

## RULE-GOV-015：0.14.x Legacy 兼容

Status: Active

规则：

打开的 0.14.x 工作继续使用 CPK v3、event v1、receipt v1/v2、context/status/evidence/verify/close、固定 review 与原子 close。其 defaults、verification profile、contract digest 和证据语义不得因 0.15 改变。

legacy 工具只在发现已有 CPK/run 或显式 legacy 命令时加载。0.15 新工作不得创建 legacy 制品。

验证：

- 0.13、0.14、0.14.1 frozen fixture 升级后能继续收口。
- 未迁移项目的 config、Truth、CPK、run、event、receipt 和 sidecar 字节保持。

停线条件：

- 普通升级改写活动 legacy 工作。
- core Archive 调用 legacy verify/close。

## RULE-GOV-016：活动制品矩阵

Status: Active

规则：

| 场景 | 活动持久制品 |
|---|---|
| R0 | 无 |
| R1 | SP + design.md + tasks.md |
| R2 pending | SP + design.md + tasks.md，禁止 Apply |
| R2 approved | SP + design.md + tasks.md + 已更新 SOT |

- SP 命名为 `docs/proposals/SP-YYYYMMDD-short-title.md`。
- specs 目录命名为 `docs/specs/<NNN-short-title>/`，且只能包含 design.md 与 tasks.md。
- completed specs 原地保留。
- CPK、plan、spec、work、CR/CP 与 ADR 不再是新工作制品。

验证：

- proposal/design/tasks 三向引用一致。
- 每个 specs 目录恰好两个文件。

停线条件：

- 新工作缺少 SP。
- design 或 tasks 重新承载 SOT 行为。

## RULE-GOV-017：最小上下文

Status: Active

规则：

AI 默认只读取用户指令、对应 SP、适用 SOT、design、tasks 与业务代码。Verify 可选。legacy evidence、完整失败输出、迁移 journal 和冷归档只在对应异常或显式审计时读取。

验证：

- P2T2C_AGENTS 只呈现核心动作与异常停线条件。

停线条件：

- 默认上下文加载冷归档或 legacy 证据。

## RULE-GOV-018：发行测试与项目质量边界

Status: Active

规则：

Archive 不运行测试、review、CI 或 release smoke。Apply 只按项目惯例运行必要检查。P2T2C 安装、升级、迁移、安全、事务、双语与兼容 smoke 只在 P2T2C 发行 CI 中显式运行。

Verify 缺席不阻断；已知 failed test 或 Verify Critical 必须如实写入 tasks Completion 并阻断 Archive。

验证：

- Archive sentinel fixture 证明未执行任何项目命令。
- release smoke 只由显式 release 目标触发。

停线条件：

- 普通任务触发 P2T2C 全量测试。
- 已知失败被标记完成。

## RULE-GOV-019：Completion 与 Archive

Status: Active

规则：

Archive 只允许：

- SP status approved 且 decision 不是 pending。
- design status ready。
- tasks 无未完成 checkbox；延期任务具有决定引用。
- Tests 不是 failed。
- Verify 不是 critical。
- Known blockers 为 none。
- Dangerous operations 不是 pending；approved 时有 authorization ref。
- R2 SOT digest 当前有效。

Archive 仅原子地把 tasks status 从 in_progress 改为 completed，不生成 receipt、sidecar 或 CR。

验证：

- Archive 正负 fixture 与原子回滚 fixture。

停线条件：

- Archive 执行外部项目命令。
- 部分写入或覆盖并发用户修改。

## RULE-GOV-020：显式文档迁移

Status: Active

规则：

普通 upgrade 不移动项目拥有文档。布局迁移只通过：

```text
p2t2c docs-migrate --dry-run
p2t2c docs-migrate --apply
p2t2c docs-migrate --rollback <report>
```

迁移逐叶移动 SP、ADR、CPK、CR/evidence 与旧 specs；归档原文保持 byte-exact。ADR 必须先有人类提供 old ADR 到 SOT DEC anchor 的显式映射；迁移器不得自动解释决策。

活动 legacy run、未闭 CPK、路径碰撞、未知引用、symlink/hardlink 或失效 DEC 映射均阻断。事务使用项目级锁、journal、备份和 after-image 校验；rollback 遇并发修改时零写入拒绝。

验证：

- dry-run 零写。
- apply/rollback byte-exact。
- 失败注入与并发 fixture。
- 迁移后冷归档不参与当前 checker。

停线条件：

- upgrade 自动搬迁文档。
- 归档原文被重写。
- 未回滚文档布局时执行模板 rollback。

## DEC-GOV-013：方法技能不具有 Truth 权威

Status: Active foundation
Date: 2026-07-10

决定：

P2T2C 自身 Truth 保持最高方法治理权威；项目方法技能只能辅助执行，不能覆盖 SOT。完整背景与后果保存在 `P2T2C_GOVERNANCE_HISTORY.md#DEC-013`。

## DEC-GOV-014：0.14 分层自治与机器证据

Status: Superseded by DEC-GOV-017 for new work
Date: 2026-08-26

决定：

CPK v3、event v1、receipt 与固定审查只保留给活动 0.14.x legacy 工作。完整背景与后果保存在 `P2T2C_GOVERNANCE_HISTORY.md#DEC-014`。

## DEC-GOV-015：0.14.1 最小上下文优化

Status: Superseded by DEC-GOV-017 for new work
Date: 2026-08-27

决定：

context/evidence/verify/close 的等价去重只保留给活动 0.14.x legacy 工作；0.15 新工作删除默认证据控制面。完整背景与后果保存在 `P2T2C_GOVERNANCE_HISTORY.md#DEC-015`。

## DEC-GOV-016：撤回保障控制面候选

Status: Superseded before release by DEC-GOV-017
Date: 2026-08-31

决定：

assurance/proof/event-v2/receipt-v3 候选不进入 0.15，因为它仍把证明流程置于业务实现之前。完整背景与后果保存在 `P2T2C_GOVERNANCE_HISTORY.md#DEC-016`。

## DEC-GOV-017：采用动作式核心与三域文档治理

Status: Active
Date: 2026-08-31
Supersedes: assurance-based 0.15 preview

决定：

P2T2C 新工作采用 Explore、Propose、Apply、可选 Verify、Archive；活动文档收敛为 proposals、specs、sot。代码质量交回项目工程体系，P2T2C 只治理 Truth、人类决策、已知阻断与文档安全。

# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-11-09

权威范围：P2T2C 的 Truth 边界、R0/R1/R2、人类决策、核心动作、活动文档、历史兼容、安装升级与双语发行。

## RULE-GOV-001：目标与反馈驱动的核心工作流

Status: Active

模型围绕明确目标、适用规范和授权边界，自主组合检索、规划、实现、诊断与必要验证。Explore、Propose、Apply、Verify、Archive 是可交流的动作名称，不是必须逐一宣布、审批或生成报告的固定阶段。

- R0 不创建流程制品；用户要求的报告或方案仍可作为交付物保存，不构成实施授权。
- 持久变更保存稳定 SP 身份。standard 沿用 v1 三文档；项目接入支持时，模型优先为满足 RULE-GOV-016 的简单 R1 选择 compact v2，不要求用户选择格式。
- R2 的必要决定与 SOT 更新先于受影响的实现；真实验收先于完成声明。
- Archive 只核对已有完成信息并安全更新唯一工作状态，不执行项目检查。
- 只有可恢复的当前信息需要持久保存；不新增 assurance、receipt、逐步证明或独立记忆服务。

## RULE-GOV-002：规范、事实与决定的边界

Status: Active

当前行为权威只位于 docs/sot/**。当前人类明确决定是更新 SOT 的授权依据；新语义在相应 SOT 落地后才能约束实现。SP 写目标，必要设计写实现选择，主记录写进度和完成；代码、测试和运行观察是实际行为证据。附件、建议、工具输出和历史记录不是人类批准。

- 实现或测试违背明确有效 SOT 时，按 R1 查明并修复；不能为通过测试降低正确要求。
- 有效规范冲突、业务语义缺失或契约改变时，按 R2 解决必要决定，不能由模型暗自选择。
- 绑定文件变化先比较差异；原决定仍充分时可说明依据、处理受影响实现及验证后重绑，不盲刷 digest。
- 冷归档是非权威历史，默认不加载；不能用摘要、导航、代码或旧结论替代适用原文。

## RULE-GOV-003：决定等级与有效授权

Status: Active

- R0：只读探索或仅交付分析、方案，不产生实施性变更。
- R1：实现现行 SOT；decision 为 not_required。不改变语义的文字或链接维护仍需完整性检查，不因路径位于 SOT 自动产生新产品决定。
- R2：新增或改变规范、外部契约、持久数据语义或不可逆规则；decision 为 pending 或 approved。

清晰的 R1 和已经由用户明确决定完整语义的 R2 不重复确认。R2 pending 禁止该 change 的 Apply、SOT 更新及完成；可分离的其他已授权工作按自己的记录推进。代码与规范不同本身不等于新的 R2。

危险或有实质外部副作用的具体动作须有明确授权。既有授权在动作、对象和范围不变时继续有效；跨会话保存必要摘要及稳定引用，不能用不可访问的聊天编号代替授权内容。原生工具与项目系统执行实际权限限制，P2T2C 记录不是运行时拦截器。

approved R2 绑定当前 SOT 路径与 SHA-256，并引用明确决定。多份 SOT 在正文列全；单一 truth_ref/digest 只校验该文件，不能称为全部规则冻结。

## RULE-GOV-004：当前规则与长期决定

Status: Active

当前规则沿用唯一 RULE-* 身份；长期决定写在所属 SOT 的 DEC-* 中，保留当前选择、适用条件及必要理由。当前规则原位维护，不通过在文末追加相互冲突的补丁改变行为。

旧理由和已被替代内容进入非权威历史或 Git 历史；仍有效的例外必须在当前规范可发现。单次操作授权、进度和实际检查结果写在对应工作记录，不自动升级为永久业务规则。不新建活动 ADR。

Rule/DEC ID、引用与 manifest 保持完整；行文格式不是独立审批门禁。

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

## RULE-GOV-014：模型自治与正确停止

Status: Active

检索顺序、任务拆解、实现方法、调试策略、检查时机、原生委派与按需复核由模型在项目约束内选择。不存在默认固定问卷、每步审批、TDD 剧本、reviewer 角色链或逐项证明。目标是单人与 AI 又快又好地交付；流程开销应与改动相称，不要求为方法选择另写论证或检查报告。

- 普通编译、测试或工具失败允许在授权内继续诊断、修复及受影响复测；已知失败阻断完成，不自动要求新产品决定。
- 继续尝试应有新证据、新假设或条件变化；目标达成后不无因扩大检查。
- 未决业务语义、危险动作缺少授权、用户改动可能被覆盖、缺少必要环境时停止受影响动作并写清下一步；保留可独立推进的已授权工作。
- 写并行须有清楚的非重叠归属和单一交付负责人；局部通过不替代合并后的必要验证。
- 项目自身必要方法与工程门禁继续有效，模型不能自行豁免；旧 legacy 的固定要求不因新核心改变。

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

## RULE-GOV-016：最小活动记录与兼容

Status: Active

| 场景 | 活动制品 |
|---|---|
| R0 | 无强制流程制品 |
| 接入已支持的简单明确 R1，模型优先选择 compact | 一份 proposal v2 |
| 其他 R1，或任意 R2 | proposal v1 + design v1 + tasks v1 |

compact 仅用于目标与验收明确、现有 SOT 足够、影响及主要依赖已知、不需要独立保存重要架构/迁移/兼容设计，且一份短记录可恢复工作的 R1。模型判断适用性，不以行数、文件数或预计耗时评分，也不询问用户是否选择模板；项目接入未支持时用 standard，仍采用精简的阅读、执行和检查方式。

SP 路径为 docs/proposals/SP-YYYYMMDD-short-title.md。standard 的 docs/specs/<NNN-short-title>/ 恰好含 design.md 与 tasks.md；既有 standard 不压缩，completed 原地保留。compact 不建占位 specs，其 proposal schema_version 为 2、shape 为 compact、work_status 保存唯一工作状态，specs_ref 为 none；R1 的 truth_ref/truth_digest 仍为 none，适用来源写正文。

compact 的正文可用段落、清单或现有项目表格；除稳定 front matter 和 Completion 外不设固定章法。受控 Tasks 章节可选；使用时校验 checkbox 与延期引用，不将代码示例中的 checkbox 当任务。standard v1 的字段及章节契约保持。

复杂度增加或风险升级时，只把活动 compact 安全扩展为 v1 standard，保持同一 SP 路径与 ID、进度和仍有效验证。必要设计与执行状态迁入相应文档；新增未决语义仍为 pending。不反向压缩、不转换 legacy、不重开 completed。

## RULE-GOV-017：按需上下文与接续

Status: Active

入口提供版本、工作身份、权威位置和必要边界；模型选择相关原文、完整条款、定义、例外和引用依赖。无编号的 SOT 仍读取适用章节；边界不清或冲突时扩大阅读。不存在每步全读入口或整份命中文件的默认要求。

有效内容可复用；目标、分支、相关 SOT、依赖或工作区变化时刷新受影响部分。manifest、索引和摘要仅定位，不成为另一份手工维护的业务规则。

compact 在 SP、standard 在 tasks 按需保存下一步、待决/阻塞、分支与代码状态、未同步内容和证据/环境限制；无接续需要不写占位交接段。优先使用原生会话能力，不新增独立状态服务。记录存在不代表代码和本机证据已同步，不隐式提交或推送；必要验证环境不可用时如实阻塞完成。

## RULE-GOV-018：真实验收与工程职责

Status: Active

项目定义必要测试、CI、设备验收和发布要求；模型按改动影响选择充分的检查，不默认每步全量回归。低影响、可逆的文字修改不为流程补造测试。已有结果仍适用时复用，相关变化或新失败才触发受影响复测。可观察结果须清楚，表达可用短段落、清单或项目已有记录，不强制六列验收表。复用结果前核对相关代码、依赖、配置、环境和原件仍有效；不确定则重新验证或明确未验证。零测试匹配不能称为通过。

完成记录说明实际方法、范围、被检查状态和来源；不复制大量日志、不强制制造提交。未运行、不适用和证据失效写正文；不向 v1 的 Tests 枚举强加新值。必要验收未完成或证据失效必须同步 Known blockers: present；standard 还保留相应未完成项，不能临近收尾自行缩小范围。

Verify 与独立复核按影响选择；未运行不自动阻断，已知 failed test 或未解决 Critical 必须如实记录并阻断完成。字段声明和 Archive 不独立证明产品正确；项目检查及行为评测负责发现缺失或错误声明。

Archive 不运行测试、review、CI 或 release smoke。P2T2C 发行测试只在本框架发布验证中显式运行，不追加到普通消费项目任务。

## RULE-GOV-019：Completion 与安全 Archive

Status: Active

compact 与 standard 共用 Tests、Verify、Known blockers、Dangerous operations、Authorization ref、Summary 六个稳定字段，沿用 v1 枚举。Archive 仅在下列声明条件满足时完成：

- SP status approved，decision 非 pending；standard design ready。
- 唯一执行状态为 in_progress；无受控未完成任务，延期有明确决定引用。
- Tests 非 failed，Verify 非 critical，Known blockers 为 none。
- Dangerous operations 非 pending；approved 时有有效授权引用字段。
- Summary 不再 pending；活动 R2 的绑定文件及 manifest 当前一致。

archive --spec 的旧接口与 JSON 语义保持；archive --proposal 定位真实主记录，compact 不虚构 tasks/design 路径。仅安全更新 compact 的 work_status 或 standard tasks 的 status。已完成记录支持幂等，不因后续 SOT 变化重绑或重开。

完成字段由模型维护，不要求用户填表。正常收口调用一次 Archive 即复用其文档检查，不依次追加结构、就绪、全仓校验；这些能力只在诊断、维护或明确项目要求时使用。结构 valid 不等于可归档；定向与全量在相同校验模式下使用相同规则。核心只检查显式声明和引用，不推断所有自然语言义务。归档不生成 receipt、sidecar 或 CR，不执行项目命令；写入前后校验、并发修改保护、中断恢复均必须有效。项目自身清理在核心成功后单独报告。

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
- 目标运行时不支持当前布局时，未先恢复兼容布局就执行模板 rollback。

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

## RULE-GOV-024：SOT 内容治理

Status: Active

SOT 保存当前有效、约束未来实现或验收的规则。一项业务语义只在一个权威位置定义，其他文档引用具体条款。按职责组织，完整保留适用条件、边界与例外；需要拆分时保持规则 ID、manifest 和引用。当前文档不承载任务流水账或一次性授权历史。

写作模板是建议，不强制字数、标题顺序或风格检查；模型按需发现重复和整理结构。结构整理不得暗改业务语义。全库清理不是每次任务或本版发布的前置条件。

## RULE-GOV-025：文档操作与恢复

Status: Active

create 只生成所选格式的机械外壳，省略形态参数时保持 standard 兼容行为；模型为适用的简单 R1 显式传入 compact，R2 初始 pending。expand 接受模型准备的合法 standard 候选，不自行解释业务正文。结构校验只读；可选就绪诊断与 Archive 共用门禁，不形成额外必经步骤。未知声明版本明确报错。

创建、扩展和 compact 归档使用目标身份、路径及前后内容绑定的事务，保留用户并发修改；扩展以原 SP 的最终切换为生效点。中断可恢复、重试不重复分配工作或覆盖已有文件。恢复、迁移和降级不能交错破坏共享布局。普通记录问题不扩大为无关工作的全仓前置检查。

## RULE-GOV-026：试用、升级与发布证据

Status: Active

0.16 compact 仍为候选能力；接入支持时由模型为适用的简单 R1 优先选择，未支持时沿用 standard。发行验证聚焦本次变更的功能、内容保护、兼容及声明支持的项目接入；已有有效证据可复用。长期效率评估、固定样本数、所有工具或跨设备试点不作为普通交付及简化方法启用的前置条件。未验证的平台与效率比例不作保证，当前实际失败仍须处理。

普通升级不改项目拥有的配置、SOT、活动记录和 legacy 字节。 回退到仍支持当前布局的运行时（如 standard v1 回到 0.15）不要求先撤销同布局迁移；未完成迁移仍必须先恢复。受支持的降级入口在替换运行时前检查目标支持的记录格式及未完成事务；任何不兼容 v2，包括 completed，均拒绝降级并列出路径，不自动转换。安装失败回滚仅恢复本次管理的状态，保留用户新增内容。

## DEC-GOV-020：按目标自治与紧凑记录的受控试用

Status: Active
Date: 2026-11-09
Supersedes: DEC-GOV-017 for new core work where stated

决定：按用户启动 0.16 实施及随后明确的“一个人跟 AI 稳定快速推进”“不要因流程降低效率”要求，以目标、真实结果、必要决定和最小接续为核心。方法由模型自主选择，简单 R1 在接入支持时优先单记录；standard v1 与 legacy 兼容保留。正常收口不叠加重复校验，不强制长期对照试点；按影响完成必要检查，保护用户内容，如实限定未验证范围。工具内部保护不转化为日常审批步骤。

# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-08-26

权威范围：P2T2C 风险与执行形态路由、Truth 边界、人类关卡、工作批次、上下文分层、机器证据、验证修复、漂移处理、执行方法、安装升级和双语发行规则。

## RULE-GOV-001：五个治理状态与三个运行循环

Status: Active

规则：

P2T2C 保留五个治理状态：

```text
意图准入 -> 风险路由与 Truth -> 工作批次执行 -> 验证与自主修复 -> 漂移检查与收口
```

Agent 运行时将它们合并为三个连续循环，默认由同一 controller 推进，不要求五次 Prompt 或 Agent 交接：

1. `准入 + 路由`：完成意图准入、风险等级、execution shape、Truth 检索和 Gate A 判断。
2. `计划 + 执行`：建立与形态相称的工作批次并实现。
3. `验证 + 修复 + 漂移 + 收口`：选择验证闭集、最多两轮自主修复、审查、漂移处理和证据投射。

- 输入可以是用户指令、Issue 或可选 `SP-*`。
- 意图清晰且无冲突时默认继续推进；同一 controller 可以在一个会话中穿过全部状态。
- 上下文压缩或 Agent 交接时，必须从文件式 brief、diff、机器证据和 Git 状态恢复，不依赖聊天记忆。
- 一个工作批次可以包含多个服务同一目标、可整体验收的相关 Task。

验证：

- `make check`
- 双语稳定枚举、CPK v3、机器证据和产物矩阵契约检查通过。

停线条件：

- 需要未定义的新工作流路径，或风险等级与 execution shape 均无法判断。

## RULE-GOV-002：Truth 边界

Status: Active

规则：

业务规则只能放在 `docs/sot/**`。ADR 解释原因。SP、CPK、work、旧版 spec/plan/tasks、prompt、运行 ledger、测试、代码注释和聊天不能成为业务规则的唯一来源。

来源优先级：

1. 当前任务中人类明确确认的决策
2. 已接受 SP、ADR
3. 当前 `docs/sot/**`
4. 当前 CPK 与执行文档
5. 当前代码与测试
6. `docs/reference/**`

验证：

- R1 CPK 使用 `truth_change: false`。
- R2 Truth Patch 应用后更新当前 SoT。

停线条件：

- 低优先级来源与高优先级来源冲突。

## RULE-GOV-003：风险、执行形态与人类关卡

Status: Active

规则：

风险等级决定 Truth 权限与人类关卡：

- `R0`：重构、测试、文档、CI 调整、只读探索，或恢复 Truth 已明确定义的行为。
- `R1`：实现现有 Truth 已覆盖的行为；创建 CPK v3，不修改 Truth。
- `R2`：修改 Truth、ADR、外部契约、持久数据语义、安全、隐私、权限或不可逆操作；创建完整 CPK v3。

正交的 `execution_shape` 决定拆分、协作和持久文档强度：

- `spike`：有界、可丢弃的探索，不交付生产或 Truth 变更；一旦要保留行为变更，必须先升级为 `bounded` 或 `architectural` 并重新路由风险。
- `bounded`：影响面清晰、单一工作批次可以整体验收。
- `architectural`：跨边界、需任务 DAG、文件所有权或分阶段集成。

形态只能 `spike -> bounded -> architectural` 单调升级，不得为减少证据或审查而降级。风险等级也只能在发现新影响后向上重新路由。

Gate A 只控制尚未决定的 R2 语义。当前用户指令已经明确决定完整语义时，记录 `gate_a: satisfied`，无需重复批准。`gate_a: pending` 时只允许不会固化语义的安全只读 `exploration` 事件；不得应用 Truth Patch、写实现或 close。

实现明确违反当前 Truth 时，Agent 默认修正实现并重新验证，不触发 Gate B。只有当建议接受漂移实现并据此修改 Truth 时才触发 Gate B；未经 Gate B 决定不得把偶然实现反向写成 Truth。

验证：

- R1/R2 CPK 使用 `docs/change_packs/CPK_TEMPLATE.md` 的 v3 front matter，并声明 `risk` 与 `execution_shape`。
- R2 `gate_a: pending` 时不得有已应用 Truth Patch 或可交付实现。
- 形态/风险升级写入 `route` 事件；Gate B 解决写入 `gate_b` 事件，并通过 `gate_b_decision`、`gate_b_ref` 和 `truth_patch_ref` 回链人类决定与 Truth Patch。

停线条件：

- 尚未决定的 R2 语义缺少 Gate A 决策。
- 接受实现并修改 Truth 缺少 Gate B 决策。

## RULE-GOV-004：Truth Rule Block 风格

Status: Active

规则：

- 当前 Truth 中的重要规则使用稳定 `RULE-{AREA}-{NNN}` 标识。
- Rule Block 先写规则，再写验证和停线条件。
- ADR 解释原因，SoT 定义当前行为。
- 历史和替代背景保留在 Governance History、迁移说明和 Git 历史中，不进入当前执行规则。

验证：

- 当前 SoT 中 Rule ID 唯一。

停线条件：

- 新规则复用当前 Active Rule ID。

## RULE-GOV-006：双单语发行根

Status: Active

规则：

- `P2T2C_EN/` 和 `P2T2C_CN/` 是两个自包含发行根。
- 受管人类与 AI 文档在各自发行根内保持单语。
- 稳定路径、风险值、execution shape、状态值、front matter 字段和脚本行为保持一致。
- 仓库根目录只作为语言选择和聚合检查入口。

验证：

- 根目录 `make check` 执行双发行根检查和结构一致性检查。
- 双发行根 checksums 与 smoke test 通过。

停线条件：

- 双发行根稳定契约或受管路径不一致。

## RULE-GOV-007：安装后的工作面

Status: Active

规则：

安装后的日常工作面是 `docs/` 和 `specs/`。内部 Prompt、技能、脚本、模板、迁移、运行 ledger 与元数据位于 `.p2t2c/`。`.p2t2c/runs/**` 是 gitignored 运行态，不是 Truth 或安装资产。

验证：

- install/upgrade smoke test。

停线条件：

- 安装或升级覆盖项目拥有的文件，或把运行 ledger 纳入发行资产。

## RULE-GOV-008：根入口文件

Status: Active

规则：

- `P2T2C_README.md` 是人类入口。
- `P2T2C_AGENTS.md` 是 AI 操作入口。
- 新安装不得创建项目通用的根级 `README.md`、`AGENTS.md` 或 `Makefile`。

验证：

- install smoke test。

停线条件：

- 新安装覆盖项目根入口文件。

## RULE-GOV-009：当前 Rule ID 完整性

Status: Active

规则：

当前非 History SoT 文档中的 `RULE-{AREA}-{NNN}` 标识必须唯一。History 是只读历史参考，不参与当前 Rule ID 唯一性或双向 lifecycle 校验。

验证：

- `make check` 扫描当前非 History SoT 文档。

停线条件：

- 当前 Active Truth 出现重复 Rule ID。

## RULE-GOV-014：Adaptive 执行方法与 Agent 自治

Status: Active

规则：

P2T2C 是决策、风险、Truth、关卡和收口的控制层。`p2t2c-adaptive-v2` 方法层可以澄清意图并规定执行纪律，但不能定义业务行为、替代 Truth、改变来源优先级或绕过 Gate A/B。

- 可自动化的 R1/R2 行为默认测试先行。测试必须先说明哪种生产缺陷会使它失败；期望值不得从被测逻辑推导。脚本、Prompt 和技能变更优先验证消费行为，并在适用时做 mutation check。生成产物、纯配置、探索性工作和无法合理自动化的情况记录豁免与替代证据。
- 每次验证修复从根因调查和可证伪假设开始。两轮修复均恢复原 implementer；复审只覆盖原 finding 与 fix diff。同一失败需要第三轮修复时停线，返回架构、Truth、范围或外部环境评估。
- `bounded` R1 生产代码在收口前进行一次独立综合审查。`architectural` R1 和所有 R2 按 ownership batch 审查，并在最终集成树上进行 global 审查；安全、权限或迁移类 R2 增加 specialist 审查。reviewer 必须与 CPK `implementer` 身份不同；所有必需审查的 Critical、Important、Minor 均为 0 才能收口。
- read-only 探索可以全面并行。写操作仅在文件所有权不重叠、隔离基线明确且指定单一集成 controller 时并行。只有 controller 可以派生 Agent；implementer 和 reviewer 不得递归 fan-out。
- 同形、独立且共享验收面的微任务合并为一次 dispatch 与一次批次审查；reviewer 必须逐项核对 brief。
- 子 Agent 按“快速/标准/最强”能力档显式选择模型与推理档。等待采用事件驱动的有界等待；仍有可执行工作时不得空等。
- `isolation: auto` 时优先使用宿主管理隔离。仅在 R2、并行或明确要求时创建或请求 worktree；删除含未跟踪或未提交内容的 worktree 必须停线并列明内容。

验证：

- CPK、work、机器事件和证据投射记录适用的方法检查点、角色身份、所有权与基线。
- 必需审查绑定 reviewer 的 base/head SHA 和最终 tree SHA。

停线条件：

- 方法产物成为业务规则的唯一来源。
- 缺少必须的审查、根因调查、隔离边界或方法豁免记录。
- implementer/reviewer 递归派生 Agent，或写并行存在所有权重叠。

## RULE-GOV-015：CPK v3、机器证据与验证配置

Status: Active

规则：

v0.14 以 `methodology.profile: p2t2c-adaptive-v2` 和 `methodology.enforcement: advisory` 试运行。只有真实 A/B 行为 eval 达到已声明效率目标且质量非劣，并通过单独的人类推广决定后，才可把新工作提升为 `required`；确定性 fixture 通过不能替代该推广证据。历史 CPK、spec、plan、tasks 和 CR 不迁移、不改写，也不得宣称尚未运行的真实 eval 已达标。

新 CPK 使用 `schema_version: 3`，并声明 execution/method/implementer、Truth Patch ref+digest、Gate B、ownership batches 与 legacy startup 字段。R1 的 Truth ref/digest 为 `none`；R2 引用一个存在的 `docs/sot/**` 文件且 SHA-256 必须匹配。architectural 的 `ownership_batches` 是逗号分隔唯一 ID；bounded/spike 为 `none`。`legacy_startup_evidence: true` 只允许 architectural 保留旧三件套。spike 不得 applied/close。

执行期间，gitignored 的 `.p2t2c/runs/<work-id>/events.jsonl` 作为按工作隔离的临时 ledger。实现支持的事件类型固定为 `exploration`、`verification`、`tdd_red`、`tdd_green`、`tdd_exemption`、`mutation`、`route`、`isolation`、`repair`、`gate_b` 与 `review`。事件按类型记录：

- 命令、退出码、验证 profile 和输出摘要；
- TDD RED/GREEN，或与 `tdd_policy` 一致的带理由豁免；
- worktree、分支与基线状态；
- route 与 Gate B 的结构化状态；repair 固定记录 `repair_round`、`hypothesis_digest`、`implementer`、`failure_digest`、`fix_base_sha`、`fix_head_sha`、`fix_diff_digest`；
- reviewer 身份、`batch|global|specialist|re_review` 角色、ownership `batch_id`、base/head SHA、finding 数量和 verdict；re_review 回链原 finding scope。

手写声明不能替代机器事件。事件/receipt 使用 `contract_digest`；契约或 Truth digest 改变后旧事件失效。close 在一个 lifecycle 中投射、运行普通 checker、确认目标和 receipt，再清理 ledger；任一步失败必须恢复原 CPK/CR 并保留 run state，不得留下半收口产物。`evidence_trust: local_consistency` 只证明本地非对抗一致性，不是签名或远程证明。

项目配置必须提供 verification profiles 与 `verification.path_mapping`。每个变更路径都必须命中映射；无映射、无 command ID 或 profile config digest 不一致是核心硬失败，不能 fallback。R2/multi-Agent primary 强制 full；governance change 额外强制 governance，两个命令全集在同一 final tree 成功。

advisory 只降低尚未推广的方法完整性要求：缺口写入 receipt 的 `evidence_warnings`，`methodology_enforcement` 与 `evidence_completeness` 必须反映 advisory/不完整，Agent 不得宣称 method-complete、无警告完成或推广就绪。schema、Gate、Truth ref/digest、路径映射、contract/final-tree、一致性和原子收口在 advisory 仍是硬门。

receipt 还投射 `gate_a`、`truth_patch_digest`、`ownership_batches`、`legacy_startup_evidence`、`path_mapping_digest`、`matched_profiles`、`matched_paths_digest`、`baseline_sha` 与 `remaining_risk_ref`，使路由、Truth、所有权、路径验证和剩余风险可复核。

R0 无 CPK。仅在 audit/residual-risk 策略要求时使用 close 的 verification profile、remaining-risk-status 与 `--remaining-risk-ref <none|ref>` 自动 CR；status=recorded 必须给非 none ref，status=none 必须 ref=none。spike 永不 close。

验证：

- Checker 解析 JSONL、拒绝陈旧 SHA/contract digest、失败的 final-tree 验证、同一 implementer/reviewer 身份、缺失的 review role 和任何非零 finding。
- 关闭的 CPK/CR 将适用验证与必需审查 100% 绑定最终 diff/tree。
- advisory 项目和历史 v2 制品保持有效，并获得可操作提示。

停线条件：

- required 模式缺少适用机器证据却收口；advisory 只能提示，不能被描述为已完成推广。
- R2 或 multi-Agent work 缺少 final-tree full，或 governance change 缺少同一 final tree 的 governance 全集。
- 删除尚未成功投射的 ledger，或用手写声明冒充运行证据。
- 非原子 close 留下半投射目标，或 advisory warning 被冒充为完整完成。

## RULE-GOV-016：产物矩阵与受管文件单一清单

Status: Active

规则：

持久产物由风险与 execution shape 共同决定：

| 场景 | 必需持久产物 |
|---|---|
| R0 | 默认无 P2T2C 文档；仅当 `p2t2c.r0.audit_mode: true` 或存在剩余风险且 `closure_on_residual_risk: true` 时自动生成极简 CR |
| bounded R1 | 单一 CPK v3，包含意图、Truth 引用、验收、策略和自动投射的 closure evidence |
| architectural R1 | CPK v3 + 单一 `work.md`；closure evidence 投射进 CPK |
| bounded R2 | 完整 CPK v3 + Truth Patch + 自动生成 CR；ADR 仅在需要长期解释时创建 |
| architectural R2 | 完整 CPK v3 + Truth Patch + `work.md` + 自动生成 CR；ADR 仅在需要长期解释时创建 |

`spike` 默认不产生流程文档且不交付可保留变更；升级后按目标形态应用矩阵。新 bounded 工作不得存在 spec/plan/tasks。只有 architectural CPK 显式 `legacy_startup_evidence: true` 时可把旧三件套作为启动证据保留；它们不成为新流程先例。

`work.md` 只记录接口、数据流、任务 DAG、所有权、集成顺序、验证和漂移，不重复 CPK 中的意图或 Truth，也不定义业务规则。

`.p2t2c/managed-files.txt` 是受管文件路径的唯一清单。`.p2t2c/manifest.yaml` 只保存指向该清单的元数据指针。Checker、安装器、升级器和 checksum 生成器共同消费 `managed-files.txt`，不维护彼此分叉的硬编码列表。

验证：

- 产物矩阵 fixture 覆盖三种风险、三种形态、审计 R0 和剩余风险 R0。
- 安装、升级、checksum 和 checker 对同一受管文件集合给出一致结果。

停线条件：

- 为 bounded R1 固定创建旧三件套或独立 CR。
- R2 在无自动 CR 的情况下关闭。
- 受管文件消费者绕过 `managed-files.txt` 或使用分叉路径清单。

## RULE-GOV-017：最小确定上下文与冷证据

Status: Active

规则：

v0.14.1-A 在不改变 `p2t2c-adaptive-v2`、R0/R1/R2、execution shape、Gate A/B、两轮修复和必需审查的前提下，将 Agent 上下文分为：

- `Hot`：精简 AI 入口、当前 route/contract、精确 Truth ref+digest、当前 CPK/work 指针和下一合法动作；始终可用。
- `Warm`：当前运行循环的单一阶段 Skill、任务 DAG、最新失败、开放 finding 和恢复 checkpoint；只在当前阶段加载。
- `Cold`：原始 events、完整失败输出、历史 CPK/CR、schema、Governance History、reference 和迁移细节；只在审计、失败诊断或冲突排查时读取。

Hot/Warm 摘要不得替代 Truth 原文。上下文胶囊必须用 manifest/config/contract/Truth/tree digest 标识来源；任一绑定变化即视为 stale，必须重建，不得用截断摘要掩盖缺失规则。

受管命令提供有界、版本化、机器可读的视图：

```text
p2t2c context --phase admit-route|execute|verify-close [--work-id ID] --json
p2t2c status --work-id ID --json
p2t2c evidence summary --work-id ID --json
```

`context` 的风险信号只是非权威 hint，不能代替 Agent 路由、CPK 或 Gate。`status` 与 `evidence summary` 是只读聚合；默认不返回原始意图、事件、命令输出或聊天。五个治理状态仍由三个 runtime loop 推进，但 Agent 入口只延迟加载 `admit-route`、`execute`、`verify-close` 三个阶段 Skill 中的当前一个；旧五 Prompt 路径作为精简兼容指针保留。

Truth manifest 只保留 rule/topic/path/digest 定位信息，不复制 Governance 正文。受管 defaults 与项目拥有的 config override 形成确定性 effective config；历史完整 config 继续有效且升级不改写。缺失的 override 可继承 defaults，但一旦显式声明某个 section/profile 却结构不完整，必须硬失败，不得静默 fallback。

close 将原始 event JSONL 存为内容寻址的冷 sidecar：

```text
docs/closure/evidence/EV-<work-id>-<source_digest>.jsonl
```

sidecar 只包含冻结 events，不包含 receipt；其安全相对路径、SHA-256 与 event count 由 closure receipt v2 绑定。CPK/CR 的 marker 只投射单行 receipt v2，默认阅读不再加载原始 events。历史 inline events + receipt v1 必须原样有效，不迁移、不改写。v2 `tree_excludes` 精确绑定 `.p2t2c/runs/**`、evidence target 和 evidence sidecar；v1 仍使用历史两项契约。

close 必须先冻结 ledger，安全创建并离线校验 sidecar/target candidate，再先安装不可覆盖的内容寻址 sidecar、后原子切换 target，最后运行普通 checker。任一失败恢复原 target，移除本事务新建且未被引用的 sidecar，并保留 run state。`local_consistency` 信任边界不扩大：不声称数字签名、远程执行真实性或对抗同时篡改。

命令事件退出非零时，完整原始输出只写入 gitignored 的 `.p2t2c/runs/<work-id>/outputs/<event-id>.log`，目录模式 `0700`、文件模式 `0600`。Agent 只自动获取净化后不超过 80 行且不超过 16 KiB 的 tail、安全路径和 digest。失败 close 保留日志，成功 close 连同 run state 删除；原始输出不得进入持久 sidecar、receipt 或默认上下文。

验证：

- 上下文命令输出符合稳定 JSON schema、严格有界，且 intent/event/output 原文不泄漏。
- 新 R0/R1/R2 收口的 receipt v2/sidecar 通过 digest/count/path/final-tree 校验；历史 receipt v1 回归通过。
- sidecar、outputs、candidate 和 target 的 symlink、hardlink、路径穿越、内容替换、并发 close 和失败回滚 fixture 通过。

停线条件：

- 胶囊摘要被当作 Truth，或 stale digest 仍被使用。
- receipt v2 缺少安全 sidecar 引用、digest/count 不一致，或 close 失败后留下新 target 引用错误 sidecar。
- 完整命令输出被投射进 CPK/CR 或默认 Agent 上下文。

## RULE-GOV-018：等价执行引擎提效

Status: Active

规则：

v0.14.1-B 只消除重复解析、重复命令和不必要的串行等待，不降低 RULE-GOV-003、014、015 的 Truth、Gate、审查、修复、final-tree 或证据要求。

- Checker 使用单进程核心，每个 config、CPK/work/CR、Truth、sidecar 和 front matter 每次检查最多解析一次；shell 只保留兼容入口。
- 只有已收口、成功、内容寻址的历史产物可跨运行缓存。cache key 必须至少绑定 artifact/CPK/sidecar digest、schema/helper/checker digest、effective config digest 和 Git object-store identity。当前 active work、pre-close proof、新 receipt、全局 Rule 唯一性与安全路径检查不得因跨 tree cache 而省略；任一 key 变化必须 miss。
- `p2t2c verify --work-id <id> --profile <profile>` 一次解析 effective config、建立 final-tree binding、运行该 profile 的稳定 command IDs，并聚合写入机器 events。只有配置声明的只读命令才可在同一 `parallel_group` 并行；任一命令改变 tree/HEAD 或失败，该验证批次失败。
- 完全相同的展开 argv 可通过配置 `covers` 关系只执行一次。coverage event 必须逐项记录 covered profile、command ID 和 profile-config digest；检查器重新展开并确认 argv digest 完全相同。仅名称、相似意图或手写声明不得建立 coverage。
- close 在同一进程内对 ledger/tree/path mapping/review/verification 做一次完整 pre-close validation，生成绑定 checker/helper/schema/effective-config/contract/final-tree/evidence digest 的 proof，再校验 candidate。安装后的普通 checker 可复用该 proof 已证明的解析结果，但仍必须检查新 target/sidecar、全局不变量和 proof 所有 binding；任一 digest/tree/path 不一致即硬失败，不得降级为手写 `Pass`。
- release smoke 拆为 `contract`、`security`、`transaction`、`migration`、`locale` 与聚合 `all`。日常反馈按 changed paths 运行适用 suite；行为相同的 EN/CN 核心只执行一次，locale/安装/迁移在独立临时目录可并行。每次发行与本 R2 最终收口仍必须在同一 final tree 完整运行一次 `smoke all`，不删减原有负向覆盖。

上述提效是可替换执行策略，不是新 Agent 策略实验。v0.14.1 不引入 dispatch 阈值、新模型/effort 升降级、review capsule、compaction 策略或审查去重；RULE-GOV-014 中现有的 Agent 自治、审查和修复边界保持不变。

验证：

- 新旧 checker 结果对同一 fixture 集语义一致；缓存 hit/miss、损坏 cache、active work 和全局不变量 fixture 通过。
- batch verify 的每个必需 command ID 都有同 final tree 的直接或等价 coverage event；伪造 covers、argv/config digest 不同被拒绝。
- close 去重前后的 receipt、停线条件和失败回滚一致；最终 `smoke all` 一次且全量通过。

停线条件：

- cache/proof/coverage 缺少任一强绑定，或命令并行改变 tree/HEAD。
- 局部 suite 被当作最终发行证据，或 EN/CN 去重隐藏 locale 差异。
- 通过执行引擎优化改变 Gate、审查、修复上限、Truth 权威或 final-tree 要求。

## 工作批次与执行文档

- R0 与 spike 默认直接执行，不创建 `specs/{feature}/`。
- bounded R1 只使用 CPK v3；architectural R1/R2 才新增 `work.md`。
- `work.md` 引用 CPK 与相关 Truth，记录任务 DAG、文件所有权、集成和批次验收。
- 旧 `spec.md`、`plan.md`、`tasks.md` 模板保留用于历史项目，不要求迁移；v0.14 自身的 014 三件套是从 0.13 启动该 R2 变更的证据。

## 验证、自主修复与收口

- 首次验证失败先诊断根因，不立即停线；明确环境性失败允许一次原样重试。
- 同一失败最多两轮修复，且恢复原 implementer；修复后只 scoped re-review finding 与 fix diff。
- 修改测试断言必须引用 Truth、CPK 或验收依据。
- Execution Doc Drift 由 Agent 自动回填 CPK/work。
- 明确违反 Truth 的实现先自动修正并重验；只有建议接受实现并修改 Truth 时触发 Gate B。
- R1 将 closure evidence 投射进 CPK；R2 自动生成 CR；R0 仅在审计模式或剩余风险策略要求时生成极简 CR。

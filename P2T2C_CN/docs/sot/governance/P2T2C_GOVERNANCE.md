# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-07-10

权威范围：P2T2C 风险路由、Truth 边界、人类关卡、工作批次、验证修复、漂移处理、执行方法、安装升级和双语发行规则。

## RULE-GOV-001：五阶段风险路由工作流

Status: Active

规则：

P2T2C 使用五阶段工作流：

```text
意图准入 -> 风险路由与 Truth -> 工作批次执行 -> 验证与自主修复 -> 漂移检查与收口
```

- 输入可以是用户指令、Issue 或可选 `SP-*`。
- 意图清晰且无冲突时默认继续推进。
- R0 不创建 CPK 或执行文档；R1/R2 创建持久化 CPK 和精简执行三件套。
- 一个工作批次可以包含多个服务同一目标、可整体验收的相关 Task。
- 所有完成的 R0/R1/R2 工作都生成 `CR-*`。

验证：

- `make check`
- CPK、spec 和 CR 契约检查通过。

停线条件：

- 需要未定义的新工作流路径或无法判断风险等级。

## RULE-GOV-002：Truth 边界

Status: Active

规则：

业务规则只能放在 `docs/sot/**`。ADR 解释原因。SP、CPK、spec、plan、tasks、prompt、测试、代码注释和聊天不能成为业务规则的唯一来源。

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

## RULE-GOV-003：风险路由与人类关卡

Status: Active

规则：

- `R0`：重构、测试、文档、CI 调整，或恢复 Truth 已明确定义的行为。
- `R1`：实现现有 Truth 已覆盖的行为；创建紧凑 CPK，不修改 Truth。
- `R2`：修改 Truth、ADR、外部契约、持久数据语义、安全、隐私、权限或不可逆操作；创建完整 CPK。

Gate A 只控制尚未决定的 R2 语义。当前用户指令已经明确决定完整语义时，记录 `gate_a: satisfied`，无需重复批准。`gate_a: pending` 时不得应用 Truth Patch 或进入执行阶段。

Gate B 只在 Truth Drift 时触发。允许的决策是修正实现、接受实现并更新 Truth，或创建新意图/ADR 后重新评估。

验证：

- R1/R2 CPK 使用 `docs/change_packs/CPK_TEMPLATE.md` 定义的 front matter。
- R2 `gate_a: pending` 且已有执行文档时，治理检查失败。

停线条件：

- 尚未决定的 R2 语义缺少 Gate A 决策。
- Truth Drift 缺少 Gate B 决策。

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
- 稳定路径、风险值、状态值、front matter 字段和脚本行为保持一致。
- 仓库根目录只作为语言选择和聚合检查入口。

验证：

- 根目录 `make check` 执行双发行根检查和结构一致性检查。
- 双发行根 checksums 与 smoke test 通过。

停线条件：

- 双发行根稳定契约或受管路径不一致。

## RULE-GOV-007：安装后的工作面

Status: Active

规则：

安装后的日常工作面是 `docs/` 和 `specs/`。内部 Prompt、脚本、模板、迁移与元数据位于 `.p2t2c/`。

验证：

- install/upgrade smoke test。

停线条件：

- 安装或升级覆盖项目拥有的文件。

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

## RULE-GOV-014：Truth 治理的执行方法

Status: Active

规则：

P2T2C 是决策、风险、Truth、关卡和收口的控制层。原生执行方法可以澄清意图或规定执行纪律，但不能定义业务行为、替代 Truth、改变来源优先级或绕过 Gate A/B。

- 支持的方法是设计澄清、风险感知 TDD、根因调试、独立审查和工作区隔离。
- 关键歧义使用设计澄清，决定仍位于当前指令、可选 SP 或 R2 CPK 中；不要求平行设计产物。
- 可自动化的 R1/R2 行为默认测试先行。生成产物、纯配置、探索性工作和无法合理自动化的情况必须记录豁免和替代证据。
- 每次验证修复都从根因调查和一个可验证假设开始。同一失败需要第三次修复时，返回架构、Truth、范围或外部环境评估。
- R1 生产代码变更和所有 R2 变更在收口前经过独立双轮审查。Critical 与 Important 问题阻断收口；Minor 问题必须修复，或作为剩余风险接受。
- `isolation: auto` 时，存在宿主管理隔离则使用；仅在 R2、并行或明确要求隔离的工作中创建或请求 worktree。并行仅限所有权边界独立的 R2 工作。

验证：

- 启用方法层的 CPK、执行文档和 CR 使用规定的方法检查点。
- R2 收口记录独立审查结论和新鲜验证证据。

停线条件：

- 方法产物被作为业务规则的唯一来源。
- 缺少必须的审查、根因调查或方法豁免记录。

## RULE-GOV-015：方法证据兼容性与强制执行

Status: Active

规则：

新安装使用 `methodology.profile: p2t2c-balanced-v1` 和 `methodology.enforcement: required`。既有项目在项目拥有的 `.p2t2c/project_config.yaml` 显式切换到 required 之前保持 advisory 兼容模式。不得仅为本方法层迁移历史 CPK、spec、plan、tasks 或 CR。新的 CPK 和 CR 模板声明 `schema_version: 2`；v2 CR 必须声明 `verification_policy: fresh_pass`，它要求有通过的验证命令且不得保留失败验证命令。

新的方法层 CPK 声明 `methodology_profile: p2t2c-balanced-v1`；required 模式 R1 CPK 还声明 `production_code_change: true|false`。在 required 模式下，其 Closure 必须记录方法证据：`RED ... Fail` 记录或带替代证据的豁免、根因记录、所需独立审查且 Critical/Important 均为零的结论，以及隔离/基线状态。启用方法层的 `CLOSE` 至少需要一条新鲜通过的验证命令，且不得保留失败验证命令。

验证：

- 治理检查仅对已声明方法层且项目配置为 required 的制品强制方法证据。
- advisory 和历史制品保持有效，同时获得可操作提示。

停线条件：

- required 模式 R2 缺少独立审查或新鲜验证证据却收口。
- required 模式下启用方法层的制品缺少必须证据。

## 工作批次与执行文档

- R0 直接执行，不创建 `specs/{feature}/`。
- R1/R2 使用精简 `spec.md`、`plan.md`、`tasks.md`。
- `spec.md` 引用对应 CPK 与相关 Truth。
- `tasks.md` 记录批次内相关 Task 和批次级验收命令。
- 不要求逐 Task Actual、`Acceptance scope`、代码 Rule 锚点或逐条 EARS Rule 标签。

## 验证、自主修复与收口

- 首次验证失败先诊断修复，不立即停线。
- 同一失败最多两轮代码或测试修复；明确环境性失败允许一次原样重试。
- 修改测试断言必须引用 Truth、CPK 或 spec 依据。
- Execution Doc Drift 由 AI 自动回填。
- Truth Drift 必须触发 Gate B。
- 所有完成工作生成 CR；正常收口决策统一为 `CLOSE`。

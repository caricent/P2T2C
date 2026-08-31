# P2T2C_GOVERNANCE_HISTORY — 治理规则 lifecycle 历史

Status: Reference
Owner: Project maintainers
Last updated: 2026-08-26

本文件保存 `P2T2C_GOVERNANCE.md` 中各规则的 lifecycle 元数据（`Source`、`Supersedes`、`Superseded by`、`Migration required`、理由、下游投射），以及已 `Superseded`/`Deprecated` 的整条规则。

> 0.12.0 起，本文件仅作为只读历史参考。当前治理不再要求 Active/History 双向 lifecycle 图，也不再由 `make check` 校验双向替代关系。`RULE-GOV-010`、`RULE-GOV-011`、`RULE-GOV-012`、`RULE-GOV-013` 已退出当前工作流；替代关系记录在 `0.11.0-to-0.12.0.md` 和 Git 历史中。

默认不读取（见 `docs/sot/manifest.yaml` 的 `forbidden_default_reads`）。仅在历史审计、对比、迁移或冲突排查时读取。

`make check` 会把本文件与 Active 层合并，对完整 lifecycle 图运行 RULE-GOV-009 完整性校验。

---

## Active 规则的 lifecycle 元数据

### RULE-GOV-001

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered workflow section
Superseded by: None
Migration required: Yes, template metadata moves to `0.4.0`

理由: 单一路径 + 例外门控让 AI 默认推进，只在关卡/冲突时停线。

下游投射:

- `P2T2C_AGENTS.md`、`.p2t2c/prompts/**`

### RULE-GOV-002

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered document-role table
Superseded by: None
Migration required: Yes, templates become bilingual in-place

理由: 业务规则集中在 SoT，避免 spec/code/chat 成为隐性 Truth 来源。

下游投射:

- `.p2t2c/templates/truth/**`、`.p2t2c/templates/execution/**`

### RULE-GOV-003

Status: Active
Source: Template maintainers；维护者更新 2026-05-24
Supersedes: previous unnumbered admission/gate section
Superseded by: None
Migration required: Yes, 模板版本 `0.10.1`

理由: Admission Summary + 人类关卡防止 AI 自行决定冲突或静默改 Truth。Gate A 现在使用明确选项选择，且 SP 草拟允许在 Gate A 前发生，因为提案文件是输入而不是 Truth 变更。无需 SoT/ADR 变更时仍快速生成 CPK；Gate A 仅保留给 SoT/ADR 变更。

下游投射:

- `.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`
- `.p2t2c/prompts/02_generate_change_pack_prompt.md`
- `.p2t2c/prompts/03_apply_change_pack_prompt.md`
- `docs/reference/archive/proposals/SP_TEMPLATE.md`
- `docs/reference/archive/proposals/README.md`
- `.p2t2c/prompts/04_generate_execution_pack_prompt.md`

### RULE-GOV-004

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered Truth document style section
Superseded by: None
Migration required: Yes, Truth templates become bilingual in-place

理由: 统一 Rule Block 风格让 Truth 同时便于人类审阅与 AI 引用。

下游投射:

- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-006

Status: Active
Source: Maintainer decision on 2026-05-19
Supersedes: `RULE-GOV-005`
Superseded by: None
Migration required: Yes, template version `0.5.0`

理由: 单文件双语文档会增加 AI 阅读时的重复上下文。双单语发行根在保留语言支持的同时，降低每次任务的阅读负担。

下游投射:

- 根目录 selector：`README.md`、`AGENTS.md`、`Makefile`
- 英文发行根：`P2T2C_EN/**`
- 中文发行根：`P2T2C_CN/**`

### RULE-GOV-007

Status: Active
Source: Maintainer decision on 2026-05-20
Supersedes: previous exposed internal asset layout
Superseded by: None
Migration required: Yes, template version `0.6.0`

理由: 收敛根目录工作面，只暴露 `docs/` 和 `docs/reference/archive/specs/`，内部资产收进 `.p2t2c/`。

下游投射:

- `.p2t2c/ownership.yaml`
- `.p2t2c/manifest.yaml`
- `.p2t2c/bin/**`
- `.p2t2c/migrations/0.5.0-to-0.6.0.md`
- 人类和 AI 入口文档

### RULE-GOV-008

Status: Active
Source: Maintainer decision on 2026-05-20
Supersedes: root-level `README.md` and `AGENTS.md` as P2T2C installed entries
Superseded by: None
Migration required: Yes, template version `0.7.0`

理由: 用 `P2T2C_README.md` 与 `P2T2C_AGENTS.md` 作为安装入口，避免与项目自有根文件冲突。

下游投射:

- `P2T2C_README.md`
- `P2T2C_AGENTS.md`
- `.p2t2c/CHECKSUMS.sha256`
- `.p2t2c/VERSION`
- `.p2t2c/P2T2C_LICENSE.md`
- `.p2t2c/templates/project_config.example.yaml`
- `.p2t2c/migrations/0.6.0-to-0.7.0.md`

### RULE-GOV-009

Status: Active
Source: 维护者决策 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.8.0`

理由: Rule 标识是 Truth、spec、task 与代码之间稳定的连接键。重复标识、悬空引用、或被取代却仍标 `Active` 的规则，会悄悄破坏这一连接。

下游投射:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-010

Status: Active
Source: 维护者决策 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.8.0`

理由: 缺少回链时，"这段代码实现了哪条规则"没有可机器校验的答案，Closure 阶段的 Truth Drift 检测失去结构化依据。

下游投射:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-011

Status: Active
Source: 维护者决策 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.8.0`

理由: EARS 语句与规则的 `Validation` 字段在两处描述同一约束。以标识绑定使一条需求从 Truth 经 spec、task 到验收步骤可追溯。

下游投射:

- `.p2t2c/templates/execution/spec.md`
- `.p2t2c/templates/execution/tasks.md`
- `.p2t2c/prompts/04_generate_execution_pack_prompt.md`

### RULE-GOV-012

Status: Active
Source: 维护者决策 2026-05-22
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.9.0`

理由: 工作流规则只增不减，若默认通读全部 active 规则，阅读基线随规则总数线性增长。按 `Phases` 字段分阶段加载并把 lifecycle 历史移出默认读取路径，使阅读成本与规则总数解耦。

下游投射:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`
- `docs/sot/manifest.yaml`
- `P2T2C_AGENTS.md`
- `.p2t2c/prompts/02_generate_change_pack_prompt.md` 至 `06_acceptance_and_closure_prompt.md`

### RULE-GOV-013

Status: Active
Source: 维护者决策 2026-05-29
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.11.0`

理由: task 链路合并和失败 triage 会改变验收命令的执行时机与失败处置路径。把 `Acceptance scope:`、triage 标签和重试次数作为自报告契约，可以在不把项目栈关键字写入治理层的前提下保持 Closure 可审计。

下游投射:

- `.p2t2c/prompts/05_execute_single_task_prompt.md`
- `.p2t2c/templates/execution/tasks.md`
- `.p2t2c/bin/check_p2t2c.sh`

### RULE-GOV-014

Status: Active
Source: 维护者决策 2026-07-10；adaptive-v2 更新 2026-08-26
Supersedes: 旧的固定方法检查点
Superseded by: None
Migration required: Yes, 模板版本 `0.14.0`

理由: 方法层从固定文档/审查仪式演进为与 execution shape 相称的 Agent 自治，同时保留 Truth、关卡、两轮修复与独立审查护栏。

下游投射:

- `.p2t2c/skills/**`
- `.p2t2c/prompts/**`
- `P2T2C_AGENTS.md`

### RULE-GOV-015

Status: Active
Source: 维护者决策 2026-07-10；machine-evidence 更新 2026-08-26
Supersedes: schema v2 的手写方法证据强制规则
Superseded by: None
Migration required: Yes, 模板版本 `0.14.0`

理由: 文本声明不能证明命令针对最终代码与当前 CPK 契约运行。v3 以 contract digest 和 final tree 做本地非对抗一致性检查，并结构化 TDD、路由、修复、Gate B 与分角色审查。

下游投射:

- `docs/reference/archive/change_packs/CPK_TEMPLATE.md`
- `.p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md`
- `.p2t2c/bin/check_p2t2c.sh`

### RULE-GOV-016

Status: Active
Source: 维护者决策 2026-08-26
Supersedes: R1/R2 固定三件套与所有风险固定 CR
Superseded by: None
Migration required: Yes, 模板版本 `0.14.0`

理由: 风险等级决定 Truth 权限，execution shape 决定执行与文档强度，使 bounded 工作减少重复产物而不削弱 R2 控制。

下游投射:

- `docs/reference/archive/change_packs/**`
- `.p2t2c/templates/execution/**`
- `.p2t2c/manifest.yaml`
- `.p2t2c/managed-files.txt`

### RULE-GOV-017

Status: Active
Source: 维护者决策 2026-08-27
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.14.1`

理由: 大上下文窗口不会自动消除注意力稀释和重复读取。将精确 Truth 与当前状态保留在 Hot/Warm，把原始 event 和失败输出放入可校验 Cold sidecar，可在不减少证据的前提下降低默认上下文。

下游投射:

- `P2T2C_AGENTS.md`
- `.p2t2c/skills/admit-route/**`、`.p2t2c/skills/execute/**`、`.p2t2c/skills/verify-close/**`
- `.p2t2c/bin/p2t2c`、`.p2t2c/bin/p2t2c_run.sh`、`.p2t2c/bin/p2t2c_close.sh`
- `.p2t2c/schemas/closure-receipt-v2.schema.json` 与上下文视图 schemas
- `docs/sot/manifest.yaml`、`.p2t2c/defaults.yaml`、`.p2t2c/templates/project_config.example.yaml`

### RULE-GOV-018

Status: Active
Source: 维护者决策 2026-08-27
Supersedes: None
Superseded by: None
Migration required: Yes, 模板版本 `0.14.1`

理由: v0.14 的最终证据和安全边界正确，但 checker、verification、close 和 release smoke 重复解析或执行同一工作。只有强 digest/tree/config 绑定下的等价去重才能作为提效，不得降低 Gate、审查、修复或全量 smoke。

下游投射:

- `.p2t2c/bin/check_p2t2c.sh` 与单进程 checker core
- `.p2t2c/bin/p2t2c`、`.p2t2c/bin/p2t2c_evidence.pl`、`.p2t2c/bin/p2t2c_close.sh`
- `.p2t2c/project_config.yaml` 与 `.p2t2c/templates/project_config.example.yaml`
- `scripts/release_smoke_test.sh` 及其分套 fixture

### RULE-GOV-019

Status: Superseded
Source: 用户与维护者决策 2026-08-31
Supersedes: adaptive-v2 固定审查矩阵与显式 verify-close 注意力分配
Superseded by: `DEC-GOV-017`
Migration required: Yes, 模板版本 `0.15.0`

理由: 质量应由最终行为、风险覆盖与缺陷逃逸衡量，而不是由统一流程动作数量衡量。风险、execution shape 与 assurance 分轴后，普通工作可保持业务焦点，未知/敏感影响仍 fail closed。

下游投射:

- `.p2t2c/lib/P2T2C/Flow.pm` 与 `p2t2c next|finish|proof`
- `.p2t2c/defaults.yaml` assurance policy
- `.p2t2c/skills/verify-close/ADAPTIVE_V3_EXCEPTION.md` 与 independent review

### RULE-GOV-020

Status: Superseded
Source: 用户与维护者决策 2026-08-31
Supersedes: 新工作默认 CPK v3/event v1/receipt v2
Superseded by: `DEC-GOV-017`
Migration required: Yes, 模板版本 `0.15.0`

理由: 精简 CPK v4 只保存业务语义，动态保障由 actual diff 派生；semantic/assurance/coverage 分离绑定避免无关改动使全部证据失效，并保持历史制品原样兼容。

下游投射:

- `docs/reference/archive/change_packs/CPK_TEMPLATE.md`
- `.p2t2c/schemas/cpk-v4.schema.json`、`event-v2.schema.json`、`closure-receipt-v3.schema.json`
- `.p2t2c/evals/adaptive-v3-scenarios.md`
- `.p2t2c/migrations/0.14.1-to-0.15.0.md`

---

## 已取代规则（全文）

### RULE-GOV-005: 英文优先单文件双语模板

Status: Superseded
Applies to: P2T2C-managed docs, prompts, templates, README files, and migration notes
Source: Template maintainers
Supersedes: `workflow: P2T2C Exception-Gated Workflow CN`, `language: zh-CN`
Superseded by: `RULE-GOV-006`
Migration required: Yes, template version `0.4.0`

规则：

P2T2C-managed human and AI workflow documents 曾采用英文优先、单文件双语呈现。

此规则已被 `RULE-GOV-006` 取代，仅作为历史 lifecycle 记录保留。
## Decision Records migrated from ADR

### DEC-013：原生 Truth 治理的方法层

Disposition: active foundation
Source: `docs/reference/archive/adr/ADR-013-superpowers-method-layer.md`

保留 P2T2C 自身 Truth 权威，并允许项目方法技能作为非权威执行层。0.15 继续保留这一边界，但不再要求方法层生成证明制品。

### DEC-014：分层自治与机器证据

Disposition: superseded by DEC-GOV-017
Source: `docs/reference/archive/adr/ADR-014-adaptive-autonomy-and-machine-evidence.md`

0.14 的 CPK v3、event v1、receipt 与固定审查继续作为 legacy 兼容语义；它们不适用于 0.15 新工作。

### DEC-015：最小上下文与等价执行提效

Disposition: superseded for new work by DEC-GOV-017
Source: `docs/reference/archive/adr/ADR-015-context-and-execution-efficiency.md`

0.14.1 的 context/evidence/verify/close 提效继续保护活动 legacy 工作。新工作通过删除默认证据控制面获得效率。

### DEC-016：业务优先保障候选

Disposition: history only; superseded before release by DEC-GOV-017
Source: `docs/reference/archive/adr/ADR-016-business-first-assurance.md`

未发布的 assurance/proof/event-v2/receipt-v3 方案因仍把证明流程置于中心而被撤回。

### DEC-017：核心动作与三域文档治理

Disposition: active
Current rule: `docs/sot/governance/P2T2C_GOVERNANCE.md#DEC-GOV-017`

0.15 新工作采用 Explore、Propose、Apply、可选 Verify、Archive，并将活动文档收敛为 proposals、specs 与 SOT。

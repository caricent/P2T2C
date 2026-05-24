# P2T2C_GOVERNANCE_HISTORY — 治理规则 lifecycle 历史

Status: Reference
Owner: Project maintainers
Last updated: 2026-05-24

本文件保存 `P2T2C_GOVERNANCE.md` 中各规则的 lifecycle 元数据（`Source`、`Supersedes`、`Superseded by`、`Migration required`、理由、下游投射），以及已 `Superseded`/`Deprecated` 的整条规则。

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
Migration required: Yes, 模板版本 `0.10.0`

理由: Admission Summary + 人类关卡防止 AI 自行决定冲突或静默改 Truth。Gate A 现在使用明确选项选择，且 SP 草拟允许在 Gate A 前发生，因为提案文件是输入而不是 Truth 变更。

下游投射:

- `.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`
- `.p2t2c/prompts/02_generate_change_pack_prompt.md`
- `.p2t2c/prompts/03_apply_change_pack_prompt.md`
- `docs/submit_proposals/SP_TEMPLATE.md`
- `docs/submit_proposals/README.md`

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

理由: 收敛根目录工作面，只暴露 `docs/` 和 `specs/`，内部资产收进 `.p2t2c/`。

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

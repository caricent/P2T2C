# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-05-22

## AI 阅读契约

- 权威范围：P2T2C 工作流治理、Truth 文档风格、语言策略、执行包规则、关卡和漂移处理。
- 必须一起读取：`P2T2C_AGENTS.md` 和 `docs/sot/manifest.yaml`。
- 按需读取：本文件按 Rule Block 的 `Phases` 字段分阶段加载。AI 在某阶段只读 `Phases` 含该阶段或 `all` 的规则，不必通读全文（见 RULE-GOV-012）。各阶段规则清单由 `make check` 从 `Phases` 字段自动生成。
- 历史层分离：lifecycle 元数据和已取代规则放在 `docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md`，默认不读，仅在审计、迁移或冲突排查时读取。
- 不得推断：AI 不得发明业务规则、静默接受冲突，或把执行文档当作 Truth。

---

## 1. 工作流

### RULE-GOV-001: 单一路径例外门控

Status: Active
Phases: all

规则：

P2T2C 使用单一路径：

```text
Proposal -> Change Pack -> 需要 SoT/ADR 变更时进入 Gate A -> 如需要则 Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

默认行为是继续推进。AI 只在关卡、冲突、缺失 Truth、检查失败或 Truth Drift 时暂停。

验证：

- `make check`
- Change Pack Admission Summary 必须决定 Fast Path 或 Blocked Path。

停线条件：

- 任何实现需要此处未定义的新工作流路径。

### 阶段

| 阶段 | 输出 | 规则 |
|---|---|---|
| Proposal | SP | 人类拥有最终意图。 |
| Change Pack（CPK） | Admission Summary、Impact Review、Fast Path 或 Blocked Path | AI 分析，不改文件。 |
| Gate A | Apply、revise、stop、split 或 reject | 仅 SoT/ADR 变更需要；人类通过明确选项决策。 |
| Truth Patch | SoT、ADR、manifest updates | 仅在需要且 Gate A 后。 |
| Execution Pack | `spec.md`、`plan.md`、`tasks.md` | 将已接受 Truth 投射为可执行工作。 |
| Coding | Code 和 task Actual results | AI 一次只执行一个任务。 |
| Acceptance | Build、test、lint、governance checks | 失败即停线。 |
| Closure Report | Close、backfill docs 或 require Truth decision | Truth Drift 触发 Gate B。 |

---

## 2. 文档职责

### RULE-GOV-002: Truth 边界

Status: Active
Phases: all

规则：

业务规则只能放在 `docs/sot/**`。ADR 解释原因。Spec、Plan、Tasks、prompt、测试、代码注释和聊天记录不能成为业务规则的唯一来源。

| 文档 | 职责 | 是否 Truth | 是否可定义业务规则 |
|---|---|---|---|
| Submit Proposal | 拟议变更 | No | 仅提案；Gate A 前可以草拟 `SP-*.md` |
| ADR | 决策背景、权衡、后果 | 决策历史 | 只记录已确认决策 |
| SoT | 当前权威项目规则 | Yes | Yes |
| Spec | 功能做什么 | No | 不可，必须引用 Truth |
| Plan | 如何实现 | No | No |
| Tasks | 可独立验收的工作 | No | No |
| Closure Report | 验收与漂移决策 | No | 不可；Truth Drift 需要人类决策 |

验证：

- Spec、plan、tasks 引用 Truth，不单独定义业务规则。

停线条件：

- 低优先级文档与当前 SoT 或已接受 ADR 冲突。

---

## 3. 准入与关卡

### RULE-GOV-003: 准入与人类关卡

Status: Active
Phases: change_pack, apply_change_pack

规则：

Change Pack 必须以 Admission Summary 开头。它必须判断 `SoT / ADR change required` 和 `Gate A required` 是 Yes 还是 No。Admission decision 必须是以下之一：

- `READY`
- `NEEDS_PROPOSAL_REPAIR`
- `CONFLICTS_WITH_TRUTH`
- `CONFLICTS_WITH_IMPLEMENTED_TRUTH`
- `ADR_REQUIRED`
- `OUT_OF_SCOPE`

`READY` 走 Fast Path。如果 `SoT / ADR change required` 为 No，直接生成 CPK，`Truth Patch Candidate` 为 `Not required`，且不需要 Gate A。如果 `SoT / ADR change required` 为 Yes，CPK 可以包含 Truth Patch Candidate，但应用前必须经过 Gate A。

非 `READY` 走 Blocked Path，且必须包含：

```text
Truth Patch Candidate: Not generated
```

应用任何 SoT 或 ADR 变更前必须有 Gate A。当现有 SoT/ADR 已定义所需规则时，生成 CPK 或执行文档不需要 Gate A。只有 Closure Decision 为以下值时才需要 Gate B：

```text
HUMAN_TRUTH_DECISION_REQUIRED
```

Gate A 前允许草拟或更新 `docs/submit_proposals/SP-*.md`。Gate A 控制 SoT 和 ADR 变更，不控制提案草拟，也不控制不修改 SoT/ADR 的 CPK 生成。

Gate A 确认必须来自 Change Pack 的 Gate A 决策选项。开放式追问不能替代明确选项选择。

验证：

- Blocked Path 提供单一 Blocking Brief 和人类决策选项。
- Change Pack 记录是否需要 SoT/ADR 变更以及是否需要 Gate A。
- Change Pack 提供有限 Gate A 决策选项，并在应用 SoT/ADR 变更前记录已选择的选项。
- AI 不自行决定冲突、不自行接受 ADR、不静默废止旧 Truth。

停线条件：

- 应用 SoT 或 ADR 变更前缺失 Gate A 选项选择。
- 需要 Gate B 但没有人类决策。

---

## 4. 停线条件

停线条件的权威清单在 `P2T2C_AGENTS.md` 第 4 节，本文件不复述。各 Rule Block 的 `停线条件` 段补充该规则特有的暂停条件。

如果 Stop-the-line Checklist 任一项为 Yes，Admission decision 不得为 `READY`。

---

## 5. Truth 文档风格与语言策略

### RULE-GOV-004: Rule Block 风格

Status: Active
Phases: apply_change_pack

规则：

Truth 文档必须便于人类审阅，也便于 AI 引用。

- 规则先于解释。
- 重要规则使用一个稳定 Rule Block。
- 使用 `RULE-DATA-001` 这类稳定 ID。
- 关键规则必须可验证。
- Active 层只保留执行期字段（`Phases`、规则、验证、停线条件）；lifecycle 元数据写入 `*_HISTORY.md`。
- 边界保持清晰：ADR 解释原因，SoT 定义当前行为。

Rule Block 格式定义在：

```text
.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md
```

验证：

- 新增或修改的 SoT 规则使用 Rule Block template。

停线条件：

- 挑战 Active 且已实现的 Truth，但没有明确 lifecycle trail。

### RULE-GOV-006: 双单语发行根

Status: Active
Phases: install_upgrade

规则：

P2T2C 以两个自包含语言专属发行根发布：

- `P2T2C_EN/` 包含英文发行版。
- `P2T2C_CN/` 包含中文发行版。
- 每个发行根都可独立安装、升级、检查，并包含自己的 `.p2t2c` 元数据、checksum、lock 文件、内部 prompt、template、script 和 Truth。
- 受管人类与 AI 工作流文档、prompt、template、README 和迁移说明在各自发行根内必须保持单语。
- 稳定工作流 token、状态值、文件路径、命令名、CLI 参数和 shell 脚本运行时输出保持英文。
- 仓库根目录只作为语言选择和聚合检查入口，不是 P2T2C 发行根。

验证：

- 仓库根目录 `make check` 会检查两个发行根。
- `P2T2C_EN/` 和 `P2T2C_CN/` 内的 `make check` 均通过。
- 两个发行根内的 `shasum -a 256 -c .p2t2c/CHECKSUMS.sha256` 均通过。
- 两个发行根的 install 和 upgrade smoke test 均通过。
- 代表性受管文档扫描确认没有同文件双语说明。

停线条件：

- 受管发行根文档重新引入同文件双语人类或 AI 指令。
- 任一发行根无法独立安装、升级或通过检查。
- 未经已接受 SP 就本地化 shell 脚本运行时输出。

### RULE-GOV-007: 根目录使用者工作面收敛

Status: Active
Phases: install_upgrade

规则：

P2T2C 安装到项目后，根目录只暴露使用者需要日常关注的 P2T2C 工作面：

- `docs/`
- `specs/`

P2T2C 内部运行资产必须放在 `.p2t2c/` 下：

- `.p2t2c/prompts/**`
- `.p2t2c/templates/**`
- `.p2t2c/templates/execution/**`
- `.p2t2c/bin/**`
- `.p2t2c/migrations/**`

用户可复制的入口模板可以保留在目标文档旁边，例如 `docs/submit_proposals/SP_TEMPLATE.md`。新增任何可见 P2T2C 根目录前，必须先经过已接受 SP 或 ADR。

验证：

- `make check`
- install smoke test 不得创建根级 `prompts/`、`templates/`、`scripts/`、`sdd/` 或 `migrations/`。
- upgrade smoke test 必须在 lock hash 匹配时移除旧的根级内部资产。

停线条件：

- P2T2C 变更重新引入根级内部资产目录。
- 升级会删除本地修改过的旧内部资产。
- 未经已接受 SP 或 ADR 新增可见 P2T2C 根目录。

### RULE-GOV-008: P2T2C 根入口文件命名

Status: Active
Phases: install_upgrade

规则：

P2T2C 安装到项目后，允许在根目录保留两个 P2T2C 专属入口文件：

- `P2T2C_README.md` 是使用者理解 P2T2C 工作流的首要文档。
- `P2T2C_AGENTS.md` 是 P2T2C 的 AI 操作入口。

P2T2C 不得在新安装中创建根级 `README.md`、`AGENTS.md`、`Makefile`、`CHECKSUMS.sha256`、`P2T2C_TEMPLATE_VERSION`、`P2T2C_LICENSE.md` 或 `project_config.example.yaml`。这些旧根文件只有在 lock hash 证明未被本地修改时，升级脚本才可移除或迁移。

如果某些 AI 工具只自动读取根级 `AGENTS.md`，使用者应在项目自己的 `AGENTS.md` 中手动引用 `P2T2C_AGENTS.md`。

验证：

- `make check`
- 新安装 smoke test 不创建旧根文件。
- `0.6.0 -> 0.7.0` upgrade smoke test 迁移未修改的旧入口文件。
- 本地修改旧 `README.md`、`AGENTS.md` 或 `Makefile` 后升级必须停线。

停线条件：

- 新安装投射任何旧根文件。
- 升级删除或覆盖本地修改过的旧入口或项目 Makefile。
- 受管文档仍把 `README.md` 或 `AGENTS.md` 当作 P2T2C 安装目标入口。

### RULE-GOV-009: Rule 标识完整性

Status: Active
Phases: apply_change_pack, acceptance

Rule:

Truth 文档中的 Rule 标识必须构成一致、可机器校验的图，扫描范围覆盖 Active 层与 `*_HISTORY.md` 合集。

- 每个 Rule Block 使用 `RULE-{AREA}-{NNN}` 标识，且在整个 `docs/sot/**`（含 History）内唯一。
- lifecycle 链必须双向：若 `RULE-A` 声明 `Superseded by: RULE-B`，则 `RULE-B` 必须声明 `Supersedes: RULE-A`，反之亦然。`None` 是唯一允许的空值。
- `Supersedes` 或 `Superseded by` 字段中出现的每个标识，都必须能在 `docs/sot/**` 中找到真实条目。
- 被任何 `Superseded by` 字段指向的规则不得仍为 `Status: Active`，必须是 `Superseded` 或 `Deprecated`。

Rationale:

Rule 标识是 Truth、spec、task 与代码之间稳定的连接键。重复标识、悬空引用、或被取代却仍标 `Active` 的规则，会悄悄破坏这一连接，让冲突的 Truth 共存而不被发现。

Validation:

- `make check` 对 `docs/sot/**`（含 History）运行 SoT 完整性扫描。
- 扫描报告重复标识、悬空 lifecycle 引用、断裂的双向链、以及被取代却仍 Active 的规则。

Stop-the-line if:

- SoT 完整性扫描报告任何错误。
- 新规则复用已有标识。

### RULE-GOV-010: 代码到 Truth 的回链锚点

Status: Active
Phases: single_task, acceptance

Rule:

实现某条 Truth 规则的代码必须携带指向该规则的回链锚点，且不得把规则文本复制进代码。

- 锚点格式为包含 `Implements: RULE-{AREA}-{NNN}` 的注释行，可用逗号分隔列出多个标识。
- 锚点只记录指针。业务规则本身留在 `docs/sot/**`，代码注释不得成为规则来源（见 RULE-GOV-002 与 Prohibited Moves）。
- 锚点中出现的每个标识，都必须能解析到 `docs/sot/**` 中 `Status` 为 `Active` 的 Rule Block。
- 对项目工作面这是软约束：当不存在 `src/**` 树时（例如空模板发行根），跳过锚点扫描。

Rationale:

Truth 通过 spec 正向投射到代码，但缺少回链时，"这段代码实现了哪条规则"这一反向问题就没有可机器校验的答案，Closure 阶段的 Truth Drift 检测也失去结构化依据。仅指针的锚点在把规则文本保持在唯一位置的同时恢复了反向链接。

Validation:

- `make check` 仅在 `src/**` 存在时运行锚点扫描。
- 扫描报告指向缺失标识或非 `Active` 规则的锚点。

Stop-the-line if:

- 锚点指向缺失或非 `Active` 的规则。
- 规则文本被移入代码注释而非以指针形式记录。

### RULE-GOV-011: EARS 验收绑定 Rule 标识

Status: Active
Phases: execution_pack, single_task, acceptance

Rule:

验收标准必须通过共享标识可追溯到它所验证的 Truth 规则。

- `spec.md` 中每条 EARS 验收语句末尾标注一个或多个 `[RULE-{AREA}-{NNN}]` 标签，命名其所验证的规则。
- `tasks.md` 中每条验收命令或可执行验收步骤标注其所验收的同一标识。
- `spec.md` 验收中标注的每个标识，也必须出现在该 spec 的 `## 0. Truth References` 表中。

Rationale:

EARS 语句与规则的 `Validation` 字段在两处描述同一约束。缺少共享标识时，它们可能漂移成不一致的措辞而不被察觉。以标识绑定使一条需求从 Truth 经 spec、task 到验收步骤可追溯。

Validation:

- spec 与 task 用所验证的规则标识标注验收。
- 被标注的标识出现在 spec 的 Truth References 表中。

Stop-the-line if:

- 某条验收标准验证的行为，其规则标识未出现在 Truth References 中。

### RULE-GOV-012: 阶段化按需阅读与 Active/History 分层

Status: Active
Phases: all

Rule:

P2T2C 治理 Truth 按阶段分层组织，使 AI 每次任务的阅读量与当前阶段相关规则数成正比，而非与规则总数成正比。

- 每个 Active Rule Block 必须声明 `Phases` 字段，取值为 manifest `phases` 列表中的稳定 token，或 `all`。
- AI 在某阶段只读取 `Phases` 含该阶段或 `all` 的规则；阶段与规则的映射由 `make check` 从 `Phases` 字段自动生成，不手工维护。
- Active 层 Rule Block 只保留 `Phases`、规则、验证、停线条件。lifecycle 元数据（`Source`、`Supersedes`、`Superseded by`、`Migration required`、下游投射）与已 `Superseded`/`Deprecated` 的整条规则，写入同目录 `*_HISTORY.md`，并列入 `forbidden_default_reads`。
- 完整性校验（RULE-GOV-009）扫描 Active 与 History 合集，分层不削弱 lifecycle 图的可校验性。

Rationale:

工作流规则只增不减：lifecycle 链强制旧规则保留为 `Superseded` 而非删除。若默认阅读"全部 active 规则"，每个任务的阅读基线会随规则总数线性增长，其中多数与当前阶段无关。按 `Phases` 字段加载，把阅读成本与规则总数解耦；把 lifecycle 历史移出默认读取路径，进一步降低固定阅读量，同时保留机器可校验的 lifecycle 图。

Validation:

- `make check` 解析每条 Active 规则的 `Phases`，校验取值均为已知 phase token，且每个 phase 至少被一条规则覆盖。
- `make check` 从 `Phases` 字段生成各阶段规则清单，可被 prompt 引用。
- History 文件在 `forbidden_default_reads` 中。

Stop-the-line if:

- 某 Active 规则缺少 `Phases`，或 `Phases` 含未知 token。
- Active 层 Rule Block 重新引入 lifecycle 元数据。

---

## 6. 执行包规则

Execution Pack 由以下文件组成：

```text
spec.md -> plan.md -> tasks.md
```

规则：

- 编码默认需要全部三个文档，除非已接受流程明确允许更小的 spec-lite 路径。
- `spec.md` 说明功能做什么，并引用 Truth。
- `plan.md` 说明策略、顺序和风险，不写完整代码。
- `tasks.md` 拆分为可独立验收的任务。
- AI 一次只执行一个任务。
- 每个 task 必须有验收命令或可执行验收步骤。
- 标记 task 完成前必须填写 Actual results。
- 验收失败不得标记完成。

执行文档只投射 Truth，不创建 Truth。

---

## 7. 漂移与收口

Closure Report 只能使用三个决策：

| Decision | 含义 |
|---|---|
| `CLOSE` | 代码、执行文档和 Truth 一致。 |
| `BACKFILL_EXECUTION_DOCS` | 代码与执行文档不同，但 Truth 未变。 |
| `HUMAN_TRUTH_DECISION_REQUIRED` | 代码改变、扩展或违反 SoT、ADR。 |

漂移标签：

| Label | 含义 | 处理 |
|---|---|---|
| No Drift | 代码、执行文档和 Truth 一致 | `CLOSE` |
| Execution Doc Drift | 代码不同于 spec、plan、tasks，但 Truth 未变 | 回填执行文档 |
| Truth Drift | 代码改变、扩展或违反 SoT、ADR | Gate B |

Gate B 选项：

1. 修代码，使代码符合 Truth。
2. 接受代码，并更新 Truth。
3. 创建或更新 SP、ADR 后再决策。

验收失败不等于收口。必须暂停并报告证据。

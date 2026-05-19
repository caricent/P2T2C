# P2T2C_GOVERNANCE — 权威工作流 Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-05-19

## AI 阅读契约

- 权威范围：P2T2C 工作流治理、Truth 文档风格、语言策略、执行包规则、关卡和漂移处理。
- 必须一起读取：`AGENTS.md` 和 `docs/sot/manifest.yaml`。
- 不得推断：AI 不得发明业务规则、静默接受冲突，或把执行文档当作 Truth。
- 停线条件：以下任一规则与已接受 CP、ADR 或当前 SoT 冲突。

---

## 1. 工作流

### RULE-GOV-001: 单一路径例外门控

Status: Active
Applies to: P2T2C workflow
Source: Template maintainers
Supersedes: previous unnumbered workflow section
Superseded by: None
Migration required: Yes, template metadata moves to `0.4.0`

规则：

P2T2C 使用单一路径：

```text
Proposal -> Change Pack -> Gate A -> Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
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
| Proposal | CP | 人类拥有最终意图。 |
| Change Pack | Admission Summary、Impact Review、Fast Path 或 Blocked Path | AI 分析，不改文件。 |
| Gate A | Apply、revise、stop、split 或 reject | 人类决策。 |
| Truth Patch | SoT、ADR、manifest updates | 仅在 Gate A 后。 |
| Execution Pack | `spec.md`、`plan.md`、`tasks.md` | 将已接受 Truth 投射为可执行工作。 |
| Coding | Code 和 task Actual results | AI 一次只执行一个任务。 |
| Acceptance | Build、test、lint、governance checks | 失败即停线。 |
| Closure Report | Close、backfill docs 或 require Truth decision | Truth Drift 触发 Gate B。 |

---

## 2. 文档职责

### RULE-GOV-002: Truth 边界

Status: Active
Applies to: P2T2C documents
Source: Template maintainers
Supersedes: previous unnumbered document-role table
Superseded by: None
Migration required: Yes, templates become bilingual in-place

规则：

业务规则只能放在 `docs/sot/**`。ADR 解释原因。Spec、Plan、Tasks、prompt、测试、代码注释和聊天记录不能成为业务规则的唯一来源。

| 文档 | 职责 | 是否 Truth | 是否可定义业务规则 |
|---|---|---|---|
| Change Proposal | 拟议变更 | No | 仅提案 |
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
Applies to: Change Pack generation and application
Source: Template maintainers
Supersedes: previous unnumbered admission/gate section
Superseded by: None
Migration required: Yes, Change Pack template becomes bilingual in-place

规则：

Change Pack 必须以 Admission Summary 开头。Admission decision 必须是以下之一：

- `READY`
- `NEEDS_PROPOSAL_REPAIR`
- `CONFLICTS_WITH_TRUTH`
- `CONFLICTS_WITH_IMPLEMENTED_TRUTH`
- `ADR_REQUIRED`
- `OUT_OF_SCOPE`

`READY` 走 Fast Path，可以包含 Truth Patch Candidate 和 Execution Pack Summary。

非 `READY` 走 Blocked Path，且必须包含：

```text
Truth Patch Candidate: Not generated
```

应用 Truth Patch 前必须有 Gate A。只有 Closure Decision 为以下值时才需要 Gate B：

```text
HUMAN_TRUTH_DECISION_REQUIRED
```

验证：

- Blocked Path 提供单一 Blocking Brief 和人类决策选项。
- AI 不自行决定冲突、不自行接受 ADR、不静默废止旧 Truth。

停线条件：

- 应用 Truth 前缺失 Gate A 批准。
- 需要 Gate B 但没有人类决策。

---

## 4. 停线条件

AI 必须在以下情况暂停：

- CP 信息不足，无法安全生成 Truth Patch。
- CP 与当前 SoT 或 ADR 冲突。
- CP 与 Active 且已实现的 Truth 冲突，且没有人类解决方案。
- 需要新增或修改 ADR。
- 继续执行需要 Proposal、已接受 CP、ADR 或 SoT 未定义的业务规则。
- 实现需要 Truth 未定义的新表、字段、接口、页面、状态、权限、AI 职责、同步对象或工作流。
- 编码使关键 Plan 假设失效。
- build、test、lint 或 governance check 失败。
- Code-to-Truth Drift 构成实质 Truth Drift。

如果 Stop-the-line Checklist 任一项为 Yes，Admission decision 不得为 `READY`。

---

## 5. Truth 文档风格与语言策略

### RULE-GOV-004: Rule Block 风格

Status: Active
Applies to: `docs/sot/**`
Source: Template maintainers
Supersedes: previous unnumbered Truth document style section
Superseded by: None
Migration required: Yes, Truth templates become bilingual in-place

规则：

Truth 文档必须便于人类审阅，也便于 AI 引用。

- 规则先于解释。
- 重要规则使用一个稳定 Rule Block。
- 使用 `RULE-DATA-001` 这类稳定 ID。
- 关键规则必须可验证。
- 边界保持清晰：ADR 解释原因，SoT 定义当前行为。

Rule Block 格式定义在：

```text
templates/truth/RULE_BLOCK_TEMPLATE.md
```

验证：

- 新增或修改的 SoT 规则使用 Rule Block template。

停线条件：

- 挑战 Active 且已实现的 Truth，但没有明确 lifecycle trail。

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

### RULE-GOV-006: 双单语发行根

Status: Active
Applies to: P2T2C-managed docs, prompts, templates, README files, migration notes, and release packaging
Source: Maintainer decision on 2026-05-19
Supersedes: `RULE-GOV-005`
Superseded by: None
Migration required: Yes, template version `0.5.0`

规则：

P2T2C 以两个自包含语言专属发行根发布：

- `P2T2C_EN/` 包含英文发行版。
- `P2T2C_CN/` 包含中文发行版。
- 每个发行根都可独立安装、升级、检查，并包含自己的 `.p2t2c` 元数据、checksum、lock 文件、prompt、template、script 和 Truth。
- 受管人类与 AI 工作流文档、prompt、template、README 和迁移说明在各自发行根内必须保持单语。
- 稳定工作流 token、状态值、文件路径、命令名、CLI 参数和 shell 脚本运行时输出保持英文。
- 仓库根目录只作为语言选择和聚合检查入口，不是 P2T2C 发行根。

理由：

单文件双语文档会增加 AI 阅读时的重复上下文。双单语发行根在保留语言支持的同时，降低每次任务的阅读负担。

验证：

- 仓库根目录 `make check` 会检查两个发行根。
- `P2T2C_EN/` 和 `P2T2C_CN/` 内的 `make check` 均通过。
- 两个发行根内的 `shasum -a 256 -c CHECKSUMS.sha256` 均通过。
- 两个发行根的 install 和 upgrade smoke test 均通过。
- 代表性受管文档扫描确认没有同文件双语说明。

下游投射：

- 根目录 selector：`README.md`、`AGENTS.md`、`Makefile`
- 英文发行根：`P2T2C_EN/**`
- 中文发行根：`P2T2C_CN/**`

停线条件：

- 受管发行根文档重新引入同文件双语人类或 AI 指令。
- 任一发行根无法独立安装、升级或通过检查。
- 未经已接受 CP 就本地化 shell 脚本运行时输出。

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
3. 创建或更新 CP、ADR 后再决策。

验收失败不等于收口。必须暂停并报告证据。

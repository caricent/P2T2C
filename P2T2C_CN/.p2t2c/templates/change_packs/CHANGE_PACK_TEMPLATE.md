# Change Pack — {SP 标题}

来源 SP: `{docs/submit_proposals/SP-...}`
生成者: AI

> Change Pack 是 AI 生成的候选包。只有 CPK 需要变更 SoT 或 ADR 时才需要 Gate A。它可以分析和提出 patch，但不能在批准前直接改文件。

---

## 准入摘要

Change Pack 必须先判断 Proposal 是否可以进入 Truth，以及是否需要变更 SoT 或 ADR。清晰且无冲突的 Proposal 走 Fast Path；有缺口、冲突、未解决 ADR 决策或已实现 Truth 冲突的 Proposal 走 Blocked Path。

| 项目 | 值 |
|---|---|
| Proposal type | Idea / Requirement / Decision / Correction / Implementation Request / Experiment |
| Related Truth、ADR | `{docs/sot/...}` / `{docs/adr/...}` / None |
| Related implemented behavior | Code / spec / tests / data / API / UI evidence, or None |
| SoT / ADR change required | Yes / No |
| Gate A required | Yes / No |
| Admission decision | READY / NEEDS_PROPOSAL_REPAIR / CONFLICTS_WITH_TRUTH / CONFLICTS_WITH_IMPLEMENTED_TRUTH / ADR_REQUIRED / OUT_OF_SCOPE |
| Reason |  |
| Required path | Fast Path / Blocked Path |

### 停线检查表

AI must fill Yes 或 No for every item. If any stop item is Yes, Admission decision must not be `READY` and the Change Pack must use Blocked Path. 清晰的 SoT/ADR 更新需求本身不是 blocker；应进入 Gate A 路由。

任一停线项为 Yes 时，Admission decision 不得为 `READY`，必须走 Blocked Path。

| 检查 | Yes/No | 证据或问题 |
|---|---|---|
| Proposal 是否存在歧义或缺失关键边界？ |  |  |
| Proposal 是否与现有 Truth 冲突？ |  |  |
| Proposal 是否与 Active 且已实现的 Truth 冲突？ |  |  |
| 是否缺失或未解决 ADR 决策？ |  |  |
| Truth 未定义的规则？ |  |  |
| 是否改变架构、数据、安全、API、AI 或权限边界？ |  |  |
| 是否需要人类做产品或架构选择？ |  |  |

---

## 影响审查

| 领域 | 影响 | 文件或说明 |
|---|---|---|
| Product | Yes/No |  |
| Architecture | Yes/No |  |
| Data | Yes/No |  |
| API | Yes/No |  |
| Client | Yes/No |  |
| Server | Yes/No |  |
| AI / Prompt | Yes/No |  |
| Testing | Yes/No |  |
| Security / Privacy | Yes/No |  |
| Docs / Governance | Yes/No |  |

---

## Change Pack 正文

只填写一个路径。

### 3A. Fast Path — CPK

仅当 Admission decision 为 `READY` 时填写本节。否则写：

```text
Truth Patch Candidate: Not generated
Reason: Admission decision is not READY.
```

如果不需要 SoT 或 ADR 变更，写：

```text
Truth Patch Candidate: Not required
Gate A required: No
Reason: Existing SoT / ADR already cover the SP.
```

如果需要 SoT 或 ADR 变更，写 `Gate A required: Yes`，填写下方 Truth Patch Candidate，并在第 4 节给出 Gate A 选项。

#### 需要更新的 SoT 文件

不需要 SoT 更新时写 `None`。

| 文件 | 变更摘要 | Rule IDs | 生命周期动作 |
|---|---|---|---|
| `{path}` |  |  | Add、Modify、Supersede 或 Deprecate |

#### ADR 动作

选择一项：

- [ ] No ADR needed
- [ ] Create ADR: `{path}`
- [ ] Update ADR: `{path}`

{说明原因。}

#### 规则变更

不需要规则变更时写 `None`。

| Rule ID | 动作 | 摘要 | 来源 | 验证 | 下游投射 |
|---|---|---|---|---|---|
| RULE-XXX-001 | Add、Modify、Supersede 或 Deprecate |  | SP、ADR |  | Spec、Tests、Code |

#### 执行包摘要

仅当 Admission decision 为 `READY` 时填写。Blocked Path 不生成 Execution Pack Summary。

- `specs/{NNN-feature}/spec.md`

- {范围}

检查项}

- {不做什么}

### Blocked Path — 阻塞摘要

仅当 Admission decision 不是 `READY` 时填写本节。Blocked Path 不生成可应用 Truth Patch Candidate。

```text
Truth Patch Candidate: Not generated
```

| 项目 | 值 |
|---|---|
| Blocker type | NEEDS_PROPOSAL_REPAIR / CONFLICTS_WITH_TRUTH / CONFLICTS_WITH_IMPLEMENTED_TRUTH / ADR_REQUIRED / OUT_OF_SCOPE |
| Evidence |  |
| Why AI must not decide |  |
| Suggested SP repair or next action |  |
| Impact if accepted |  |

人类决策选项：

1. {可决策选项 A}
2. {可决策选项 B}
3. {可决策选项 C}

#### Required only for `CONFLICTS_WITH_IMPLEMENTED_TRUTH`

#### 仅 `CONFLICTS_WITH_IMPLEMENTED_TRUTH` 必填

| 项目 | 值 |
|---|---|
| Existing implemented behavior |  |
| Affected code / spec / tests / data / API / UI |  |
| Migration or compatibility risk | None / Low / Medium / High |
| Old Rule lifecycle action | Keep / Modify / Supersede / Deprecate |

---

## Gate A 决策选项

AI 生成本 Change Pack 后的动作：

如果 `Gate A required` 为 No，写：

```text
Gate A required: No
Reason: CPK does not modify SoT or ADR.
```

如果 `Gate A required` 为 Yes，让人类只选择一项。界面支持选项选择时直接使用选项；否则展示本列表并等待人类选择。

选项：

1. Approve and apply Truth Patch.
2. Revise Proposal.
3. Resolve Conflict.
4. Create / Update ADR.
5. Reject Proposal.
6. Split Proposal.

已选择的 Gate A 决策：

{待填写}

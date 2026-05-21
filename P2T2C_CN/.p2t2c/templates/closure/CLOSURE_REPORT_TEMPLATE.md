# Closure Report — {功能名}

Spec: `specs/{NNN-feature}/spec.md`
Plan: `specs/{NNN-feature}/plan.md`
Tasks: `specs/{NNN-feature}/tasks.md`

> Closure Report 是 Acceptance 后的收口文件，用来判断是否可以关闭，以及代码是否领先 Truth。

---

## 验收摘要

| Check | Result | Evidence |
|---|---|---|
| Build | Pass、Fail 或 NA |  |
| Tests | Pass、Fail 或 NA |  |
| Lint、Typecheck | Pass、Fail 或 NA |  |
| Governance check | Pass、Fail 或 NA | `make check` |
| Manual acceptance | Pass、Fail 或 NA |  |

---

## 已实现文件

| File | Change summary |
|---|---|
| `{path}` |  |

---

## Spec、Plan、Tasks 一致性

| Item | Yes/No | Notes |
|---|---|---|
| Spec implemented |  |  |
| Plan followed |  |  |
| All tasks completed |  |  |
| Task actual results filled |  |  |

---

## 漂移检查

### 无漂移证据

- {如果无漂移，写证据；否则写 N/A。}

### 执行文档漂移

Tasks 有差异，但不影响 Truth：

- {None 或差异列表}

建议回填：

### Truth 漂移

代码改变、扩展或违反 SoT、ADR：

| 漂移 | 代码行为 | Truth 规则 | 建议解决方式 |
|---|---|---|---|
| {item} | {behavior} | {rule} | 修代码、更新 Truth 或创建新的 SP/ADR |

如果本节非空，Closure Decision 必须是 `HUMAN_TRUTH_DECISION_REQUIRED`。

---

## 收口决策

必须且只能选择一个：

- `CLOSE`：代码、执行文档、Truth 一致。
- `BACKFILL_EXECUTION_DOCS`：只有 spec、plan、tasks 需要回填；Truth 不变。
- `HUMAN_TRUTH_DECISION_REQUIRED`：存在 Truth Drift，需要 Gate B。

决策: `{CLOSE | BACKFILL_EXECUTION_DOCS | HUMAN_TRUTH_DECISION_REQUIRED}`

---

## 存在 Truth Drift 时需要 Gate B

如果 Decision 是 `HUMAN_TRUTH_DECISION_REQUIRED`，人类必须选择：

1. 修代码，使代码符合 Truth。
2. 接受代码，并更新 Truth。
3. 创建或更新 SP、ADR 后再决策。

人类决策：

{待填写}

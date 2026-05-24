# SP-{YYYYMMDD}-{short-title}

---

## 一句话需求

{用一句话描述要新增或调整什么。}

---

## 背景

为什么现在要做？当前问题是什么？

---

## 最终需求口径

写最终规则，不写多个模糊备选。

- {规则 1}
- {规则 2}
- {规则 3}

---

## 非目标

本次明确不做：

- {不做事项 1}
- {不做事项 2}

---

## 假设与待决问题

- {已知假设；如无，写 None}

- {需要人类选择的事项；如无，写 None}

- {已知会影响的 RULE-ID；如无，写 None}

UI；如无，写 None}

---

## 影响范围初判

| 领域 | 影响 | 说明 |
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

---

## 与现有 Truth 的已知冲突

- {如无，写 None}

---

## 初步验收标准

- When {触发条件}, the system shall {预期行为}.
- The system shall not {禁止行为}.
- Counterexample: {本次不应被接受或不应发生的行为；如无，写 None}

---

## 给 AI 的处理要求

请基于本 SP 生成 Change Pack。

在 Gate A 之前，可以创建或更新本 `SP-*.md` 文件。除此之外，不要修改 Truth、ADR、执行文档、代码、测试或数据库文件。

生成 Change Pack 后如需要 Gate A，请用选项选择方式让人类决策，不要用开放式追问代替。

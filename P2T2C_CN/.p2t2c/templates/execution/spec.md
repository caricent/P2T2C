# Spec {NNN}: {功能名称}

来源 CP: `{docs/change_proposals/CP-...}`
相关 ADR: `{docs/adr/ADR-... | None}`

---

## Truth 引用

本 spec 只投影以下 Truth，不新增业务规则：

| Truth 文件 | Rule IDs 或章节 |
|---|---|
| `{docs/sot/...}` | `{RULE-...}` |

必须暂停：

- 实现需要 Truth references 之外的新规则。
- Spec 与 SoT 冲突。
- 验收标准要求 SoT 未定义的行为。

---

## 背景与目标

### 用户故事

As a {角色}, I want to {行为}, so that {价值}.

### 触发原因

{为什么现在做。}

### 非目标

- {本 spec 不做什么。}

---

## 功能描述

{按功能分组描述。}

---

## 配置

| 参数 | 允许值 | 默认值 | 描述 | Truth 来源 |
|---|---|---|---|---|
| {name} | {values} | {default} | {desc} | {RULE-ID} |

---

## 验收标准（EARS）

每条语句末尾标注其所验证的 Truth 规则标识（RULE-GOV-011）。每个被标注的标识也必须出现在第 0 节 Truth References 中。

- When {触发条件}, the system shall {预期行为}. [RULE-...]
- While {持续条件}, the system shall {持续行为}. [RULE-...]
- The system shall not {禁止行为}. [RULE-...]

---

## 领域设计

根据项目类型引用或填写：

---

## Truth Drift 观察清单

实现过程中如出现以下情况，必须暂停：

- {可能导致 Truth Drift 的边界}

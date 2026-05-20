# Tasks {NNN}: {功能名称}

Based on: `spec.md` + `plan.md`
规则：完成 task 前必须运行验收命令，并回填 Actual。

---

## Task 粒度规则

- 一个 Task = 一个可独立验收的交付物。
- 一个 Task 约等于一次有意义的 commit。
- 一个 Task 建议涉及文件不超过 5 个。
- 超出范围时拆分。
- 一次只执行一个 Task。

---

## Phase 1: {阶段名}

### Task 1.1: {任务名称}

Truth references:

- `{docs/sot/...}` — `{RULE-...}`

- `{path}` — Add 或 Modify

1. {做什么；不写完整代码。}
2. {关键数据、枚举、接口路径、边界条件。}

- {如发现 Execution Doc Drift 或 Truth Drift，记录并暂停或留到 Closure。}

---

## 最终验收关卡

- [ ] Closure Decision is one of: `CLOSE`, `BACKFILL_EXECUTION_DOCS`, `HUMAN_TRUTH_DECISION_REQUIRED`.

- [ ] 所有 tasks 已完成。
- [ ] 所有 task Actual 结果已填写。
- [ ] feature-level build/test/check 已通过。
- [ ] 已生成 Closure Report。
- [ ] Closure Decision 是以下之一：`CLOSE`、`BACKFILL_EXECUTION_DOCS`、`HUMAN_TRUTH_DECISION_REQUIRED`。

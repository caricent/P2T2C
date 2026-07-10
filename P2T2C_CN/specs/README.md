# 执行文档

R1/R2 在这里保存精简执行三件套：

```text
specs/{NNN-feature}/
  spec.md
  plan.md
  tasks.md
```

- `spec.md` 必须在 front matter 中引用对应 `docs/change_packs/CPK-*.md`。
- `plan.md` 记录实现策略、影响范围和风险。
- `tasks.md` 记录一个可整体验收工作批次内的多个相关 Task 和批次级验收。
- 精简三件套还记录行为/测试策略、隔离/审查检查点和批次级方法证据，但不恢复逐 Task Actual 记录。
- R0 不创建执行文档。
- 不要求逐 Task Actual、`Acceptance scope` 或逐条 Rule ID 标签。

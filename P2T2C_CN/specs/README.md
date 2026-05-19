# 执行文档

这里存放 P2T2C 的执行文档。

每个功能一个目录：

```text
specs/001-feature-name/
  spec.md
  plan.md
  tasks.md
```

规则：

- `spec.md` must cite Truth.
- `plan.md` states strategy only; it must not contain full implementation code.
- `tasks.md` must include acceptance commands and Actual backfill locations.

- `spec.md` 必须引用 Truth。
- `plan.md` 只写策略，不写完整代码。
- `tasks.md` 必须包含验收命令和 Actual 回填位置。
- Acceptance 后必须生成 Closure Report。

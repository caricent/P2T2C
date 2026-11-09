# Specs

模板仓库此目录只保留本说明，不预置设计或任务实例。项目确实需要 standard 时再创建对应工作目录。

只有 standard 使用 `docs/specs/<NNN-short-title>/design.md` 与 `tasks.md`。design 保存必要实现设计，tasks 保存有用的执行事项与完成结果；不把每个 checkbox 当作单独审批或完整验收阶段。compact 只维护 SP，不建立占位 specs 目录。

已有 standard 保持原身份。完成后目录不移动，仅将 tasks status 原地更新为 completed；必要检查按本次交付的影响范围安排。

延期任务使用 `[-]`，并在同一行记录稳定的人类决定引用，例如 `decision: user-20260831-defer-x`；`none`、`pending` 或 `unknown` 不能作为依据。

历史 plan/spec/tasks/work 位于 `docs/reference/archive/specs/`，不转换为新格式，也不具有当前权威。

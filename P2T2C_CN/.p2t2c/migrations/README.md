# P2T2C 模板迁移

最新迁移：`0.14.0-to-0.14.1.md`，在保留 adaptive-v2 契约的同时降低上下文与重复执行。

此目录记录 P2T2C 工作流模板迁移。

迁移文件说明旧项目如何安全采用新的 P2T2C release，同时不修改项目拥有的业务文件。

命名：

```text
{from-version}-to-{to-version}.md
```

规则：

- 迁移说明只描述工作流、模板和 governance 变化。
- Business Truth、ADR、spec、code、tests 和历史 Closure Report 不会自动迁移。
- 新工作流规则适用于升级后创建的工作；历史 v2 产物继续有效。

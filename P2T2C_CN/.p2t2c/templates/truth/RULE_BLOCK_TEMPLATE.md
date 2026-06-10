# Rule Block 模板

当前 Truth 中的重要规则使用稳定 Rule ID。历史与替代背景写入迁移说明、Governance History 或 Git 历史，不进入当前执行 Rule Block。

```text
## RULE-{AREA}-{NNN}：{规则名称}

Status: Active

规则：

{清晰、可执行、可验证的当前规则。}

验证：

- {自动化检查或人工验收}

停线条件：

- {什么情况下必须暂停找人确认}
```

约束：

- 当前非 History SoT 文档中的 Rule ID 必须唯一。
- 不要求代码添加 `Implements: RULE-*` 注释。
- 不要求每条 EARS 或 Task 验收逐条标注 Rule ID。

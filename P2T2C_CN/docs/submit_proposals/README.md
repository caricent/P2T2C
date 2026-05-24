# 提交提案

这里是 P2T2C 的 Proposal 入口。

## 何时创建 SP

- 新增功能。
- 调整需求。
- 修改业务规则。
- 修改架构、数据、AI、权限、同步或测试口径。

## 命名

```text
SP-YYYYMMDD-short-title.md
```

## 工作方式

1. 复制 `SP_TEMPLATE.md` 为 `SP-YYYYMMDD-short-title.md`，或让 AI 基于模板创建该 SP 文件。
2. 写清最终需求和非目标。
3. 让 AI 生成 Change Pack，并先做 Admission Summary。
4. 如需要 Gate A，AI 必须给出明确决策选项并等待人类选择，之后才可修改 Truth 或执行文档。
5. 如果 Change Pack 走 Blocked Path，先修补 Proposal、解决冲突或处理 ADR。

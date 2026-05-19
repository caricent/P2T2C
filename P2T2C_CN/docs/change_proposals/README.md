# 变更提案

这里是 P2T2C 的 Proposal 入口。

## 何时创建 CP

- 新增功能。
- 调整需求。
- 修改业务规则。
测试口径。

## 命名

```text
CP-YYYYMMDD-short-title.md
```

## 工作方式

1. Copy `CP_TEMPLATE.md`.

1. 复制 `CP_TEMPLATE.md`。
2. 写清最终需求和非目标。
3. 让 AI 生成 Change Pack，并先做 Admission Summary。
4. 如果 Change Pack 走 Fast Path，Gate A 确认后再允许 AI 修改 Truth 和执行文档。
5. 如果 Change Pack 走 Blocked Path，先修补 Proposal、解决冲突或处理 ADR。

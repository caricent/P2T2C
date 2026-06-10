# 收口报告

所有完成的 R0、R1、R2 工作都在这里创建：

```text
CR-YYYYMMDD-short-title.md
```

CR 使用 YAML front matter 记录风险等级、CPK、执行包、Truth Drift 和 `CLOSE` 决策，并在正文记录实际验证命令、结果、未运行原因和剩余风险。

Execution Doc Drift 由 AI 自动回填。Truth Drift 必须先通过 Gate B 解决，之后才能以 `CLOSE` 收口。

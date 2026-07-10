# 收口报告

所有完成的 R0、R1、R2 工作都在这里创建：

```text
CR-YYYYMMDD-short-title.md
```

CR 使用 YAML front matter 记录风险等级、CPK、执行包、Truth Drift 和 `CLOSE` 决策。新的 CR 使用 `verification_policy: fresh_pass`，它要求至少一条新鲜通过的验证命令且不得保留失败验证。正文记录实际验证命令、结果、未运行原因和剩余风险。启用方法层的工作还记录测试先行证据或豁免、根因修复证据、独立审查和隔离/基线状态。

Execution Doc Drift 由 AI 自动回填。Truth Drift 必须先通过 Gate B 解决，之后才能以 `CLOSE` 收口。

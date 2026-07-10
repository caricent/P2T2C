---
name: p2t2c-independent-review
description: 在收口前独立审查 R1 生产代码和 R2 P2T2C 工作。
---

# 独立审查

仅使用变更文件、CPK、spec、Truth、ADR 和验证证据来审查完成的工作批次。按两轮进行：

1. 审查 Truth、CPK、spec、风险分级和 Gate A/B 状态是否合规。
2. 审查正确性、安全、可维护性、测试和验证质量。

Critical 和 Important 问题会阻止 `CLOSE`，直到修复并重新验证。Minor 问题必须修复，或在 CR 的剩余风险中明确接受。实现者在收口前必须独立验证审查结论。

R1 只要修改生产代码就必须使用本方法。R2 始终必须使用。除非项目配置提高要求，否则 R0 使用常规自审。

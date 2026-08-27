---
name: p2t2c-verify-close
description: 聚合验证、修复、审查、漂移与原子收口，默认只读有界证据摘要。
---

# 验证、修复与收口

## 输入

1. 运行 `p2t2c context --phase verify-close --work-id <id> --json`、`p2t2c status --work-id <id> --json` 和 `p2t2c evidence summary --work-id <id> --json`。
2. 按 changed-path mapping 运行必需 profile；R2/multi-Agent 必须 full，governance change 还需 governance，全部绑定同 final tree。

## 输出

- 失败先根因诊断，最多两轮恢复原 implementer，并用 scoped `re_review` 回链修复。
- 按既有规则完成 batch/global/specialist review，所有 finding 为 0。
- 对照 Truth/CPK/work 处理漂移；只有接受实现并改 Truth 才 Gate B。完成后调用 close，不手写 Pass。

## 停线

status 未显示 `closable`、必需证据/审查缺失、任一 finding 非零、第三轮同失败、未解决 Gate 或 close 回滚时不得声称 CLOSE。只在审计/诊断时读 raw sidecar/log。

---
artifact: closure_report
schema_version: 2
id: CR-YYYYMMDD-short-title
risk: R0
change_pack: none
execution_pack: none
truth_drift: none
decision: CLOSE
verification_policy: fresh_pass
---

# CR-YYYYMMDD-short-title

## 完成摘要

- 实现范围：
- 相关 Truth / ADR：

## 验证证据

| 实际命令或步骤 | 结果 | 备注或未运行原因 |
|---|---|---|
| `{command}` | Pass / Fail / Not run |  |

## 漂移检查

- Execution Doc Drift：None / 已自动回填
- Truth Drift：None / 已通过 Gate B 解决

## 方法证据

- 方法配置：`p2t2c-balanced-v1` / 不适用
- 测试先行：`RED <命令> => Fail`，或 `豁免：<原因>；替代证据：<命令/结果>`：
- 根因修复记录：不适用 / 根因、假设和修复轮次：
- 独立审查：`通过；Critical：0；Important：0；Minor：<数量与处理>` / 不需要：
- 隔离与基线：不适用 / 状态与验证：

## 剩余风险

- None

## 收口

决策：`CLOSE`

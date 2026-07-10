---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260710-superpowers-method-layer.md
---

# Spec 013：Superpowers 方法层

## 目标与非目标

- 目标：在不削弱 P2T2C 治理的前提下提供五项原生工程方法。
- 非目标：要求外部插件或重写历史制品。

## Truth 引用

| Truth / ADR | 相关规则或决策 |
|---|---|
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | RULE-GOV-014、RULE-GOV-015 |
| `docs/adr/ADR-013-superpowers-method-layer.md` | 原生方法层决策 |

## 验收行为

- 新安装获得全部五项原生方法技能和 required balanced 配置示例。
- 缺少方法配置的项目保持 advisory 兼容。
- required 模式下启用方法层的 R2 Closure 缺少方法证据和独立审查时不能通过治理检查。

## 行为与测试策略

- 测试先行行为：checker fixture 覆盖 required 与 advisory 方法强制执行。
- 豁免及替代证据：发行一致性、checksum 和安装/升级 smoke test 验证受管资产交付。

## 边界

- 新的语义边界、Truth 冲突或高风险事项必须返回意图准入阶段。

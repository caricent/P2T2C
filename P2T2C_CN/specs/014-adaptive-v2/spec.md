---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260826-adaptive-v2.md
legacy_startup_evidence: true
startup_profile: p2t2c-balanced-v1
---

# Spec 014：分层自治与机器证据

> 本文件是 2026-08-26 按 v0.13 流程启动 R2 变更时创建的执行证据。它不表示 adaptive-v2 仍要求 spec/plan/tasks，也不得覆盖当前 CPK 或 SoT。

## 目标与非目标

- 目标：按风险与 execution shape 缩放流程产物，并以 final-tree 机器证据替代手写通过声明。
- 非目标：削弱 Truth/Gate、新增 Superpowers 运行依赖或改写历史制品。

## Truth 引用

| Truth / ADR | 相关规则或决策 |
|---|---|
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | RULE-GOV-001、003、014、015、016 |
| `docs/adr/ADR-014-adaptive-autonomy-and-machine-evidence.md` | 分层自治与机器证据决策 |

## 验收行为

- R0 默认零文档，bounded R1 只有 CPK v3，architectural 使用单一 work，R2 自动 CR。
- bounded 拒绝旧三件套；本 014 因 architectural + CPK legacy=true 保留启动证据。W1/W2/W3 是唯一 ownership IDs，各需 batch review。
- R2 Truth ref 指向单一 SoT 且 digest 匹配；每个 changed path 必须命中 mapping。
- advisory 仍硬拒 Gate/Truth digest/mapping/contract/final tree/atomic close；方法缺口只成为结构化 warning 与不完整 completeness，不得冒充 complete。
- 双语发行、历史 v2 兼容、安装升级和受管文件清单保持安全一致。

## 行为与测试策略

- 确定性 fixture 覆盖 parser/schema、产物矩阵、Gate、local-consistency 负向输入与安装升级，但不证明真实 Agent 行为或对抗防篡改。
- 行为 eval 才评估 control/treatment 路由、质量与效率；本批次不伪称已运行或达标。

## 边界

- 新的业务、安全、权限或持久数据语义必须返回 Gate A；明确违反 Truth 的实现先自动修正。

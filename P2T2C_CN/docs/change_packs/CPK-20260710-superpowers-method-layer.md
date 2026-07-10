---
artifact: change_pack
schema_version: 2
id: CPK-20260710-superpowers-method-layer
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-balanced-v1
---

# CPK-20260710-superpowers-method-layer

## 意图与范围

- 目标：为 P2T2C 增加原生、由 Truth 治理的执行方法层。
- 非目标：捆绑 Superpowers、替换五阶段，或让方法成为业务 Truth。
- 来源：2026-07-10 已获批准的用户方案。

## 风险路由

- 风险等级及理由：R2，因为治理 Truth、ADR 策略、模板、检查和发行升级行为发生变化。
- 相关 Truth / ADR：RULE-GOV-014、RULE-GOV-015、ADR-013。
- 影响范围：两个单语发行根和受管安装/升级资产。

## Truth Patch

应用 RULE-GOV-014 和 RULE-GOV-015。P2T2C 保持控制层；方法证据采用 schema-aware 检查，历史项目继续兼容 advisory。

## 工作批次

- 建议 feature 目录：`specs/013-superpowers-method-layer/`
- 批次边界：skills、Prompt、模板、治理检查、迁移、来源说明和双语一致性。
- 验收闭集：发行检查、checksum 校验和安装/升级 smoke test。

## 方法检查点

- 测试先行行为或豁免：配置/文档工作流；使用发行检查和 smoke-test fixture 验证，而非生产行为测试。
- 隔离与基线：宿主管理的工作区；工作前检查干净基线。
- 是否需要独立审查：是

## 阻塞项

- None

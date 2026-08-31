---
artifact: change_pack
schema_version: 3
id: CPK-20260831-business-first-assurance
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-adaptive-v2
execution_shape: architectural
production_code_change: true
multi_agent: true
work_pack: specs/015-business-first-assurance/work.md
implementer: root-controller
tdd_policy: required
governance_change: true
specialist_review_required: true
truth_patch_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_patch_digest: 46209ac7c8b68a933d94fa5130b168f29207d4b39f8fb78fe473f1dbdea7c982
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: W1,W2,W3,W4
legacy_startup_evidence: false
---

# CPK-20260831-business-first-assurance

## 意图与边界

- 发布 P2T2C 0.15，将默认流程精简为 Explore、Propose、Apply、可选 Verify、Archive。
- 活动文档收敛为 docs/proposals、docs/specs 与 docs/sot；SP 承担 why/what，design 写 how，tasks 记录执行与完成。
- 删除未发布的 assurance/proof/event-v2/receipt-v3/next/finish 方案；项目测试、CI 和 code review 继续属于项目工程体系。
- 保留 R0/R1/R2、单一人类 decision、危险操作授权、用户改动保护和 0.14.x legacy 收口兼容。
- 新增显式、可回滚的 docs-migrate；普通 upgrade 不移动项目拥有文档。

## 路由与验收

- R2 / architectural：治理 Truth、活动文档布局、checker、Archive、迁移事务、安装升级与双语发行共同改变。
- 新 R1/R2 只能使用 SP + design.md + tasks.md；R0 零文档。
- Archive 不运行项目命令，只在已知阻断清零后原子更新 tasks status。
- 打开的 CPK v3/event v1/receipt v1/v2 原样可继续收口。
- 双语 check、core/security/transaction/migration/locale smoke 与真实 0.14.1 升级 fixture 通过。

## Truth Patch 与所有权

- Truth Patch：RULE-GOV-001 至 020 中的核心动作、三域文档、Decision Record、质量边界、legacy 兼容与显式迁移规则。
- W1：Truth、Decision Records、SP/design/tasks 契约与模板。
- W2：Documents validator、Archive 与 CLI。
- W3：docs-migrate、安装升级、路径/事务安全和 legacy 兼容。
- W4：README/AGENTS、manifest/inventory、双语 parity 与 release smoke。
- 单一集成 controller：root-controller；批次写范围不重叠。

## 方法检查点

- 当前 0.15 自身继续按 adaptive-v2 CPK v3 收口，不使用新 core 为自己降低证据要求。
- W1-W4 独立审查、global 与 compatibility specialist 清零后执行 legacy full/governance 验证。
- 当前没有接受实现漂移并反向修改 Truth 的提议，Gate B 不触发。

## 阻塞项

- None。

## 收口证据

等待实现、独立审查、最终验证与 legacy R2 收口。

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

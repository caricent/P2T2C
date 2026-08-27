# ADR-014：分层自治与机器证据

Status: Accepted
Date: 2026-08-26
Change Pack: `docs/change_packs/CPK-20260826-adaptive-v2.md`
Truth Patch: `docs/sot/governance/P2T2C_GOVERNANCE.md`
Truth Patch SHA-256: `1c3b2bc2666b1acb6846c1c243880890d94c0e00c78c0cc69e40b48058219f92`

## 背景

v0.13 保留了正确的 Truth、R0/R1/R2、Gate A/B 和新鲜验证边界，但 R1/R2 固定创建 CPK、spec、plan、tasks 和 CR，重复记录目标、Truth、验证和方法证据。Checker 主要依赖 Markdown 声明，不能证明命令、审查和最终代码来自同一 tree。

Superpowers v6.2/v6.3 展示了按工作隔离的临时 ledger、恢复原 implementer、scoped re-review、spike/bounded/architectural 分档、同形微任务批处理、禁止递归 fan-out、文件式交接和事件式等待。它们适合转译为 P2T2C 的执行纪律，但不能覆盖 P2T2C 的 Truth 权威与人类关卡。

## 决策

1. 保留 R0/R1/R2 作为 Truth 权限轴，新增 `execution_shape: spike | bounded | architectural` 作为执行强度轴，且只允许向上升级。
2. 保留五个治理状态，但 runtime 合并为三个连续 Agent 循环，不强制五次交接。
3. R0 默认零文档；bounded R1 使用单一 CPK v3；architectural 使用 CPK v3 + work；R2 保留 Truth Patch 并自动生成 CR。ADR 仅在需要长期解释时创建。
4. CPK 绑定 Truth digest/ownership/legacy。ledger 增 exploration/re_review；receipt 投射 `methodology_enforcement`、`evidence_completeness`、`evidence_warnings`、mapping、baseline 和 risk ref。
5. 采用 adaptive review、并行、模型路由和两轮修复边界。只有 controller 可以派生 Agent；实现明确违反 Truth 时先自动修正，只有接受实现并修改 Truth 才触发 Gate B。
6. `.p2t2c/managed-files.txt` 成为 checker、安装、升级和 checksum 的受管文件唯一清单；`.p2t2c/manifest.yaml` 只保存指针。
7. v0.14 advisory 仍把 Gate/Truth digest/path mapping/contract/final tree/原子 close 作为硬门；方法缺口是结构化 warning 且 completeness 不完整。真实 A/B + 人类决定后才推广 required。

## 未采用的上游做法

- 不要求所有任务在实施前获得统一人工批准；Gate A 仍只处理尚未决定的 R2 语义。
- 不让 spec 或 plan 覆盖 SoT，不增加 Superpowers 运行时依赖。
- 不采用五轮修复、搁置 Important finding、每任务强制 worktree 或每 Task 一个 Agent。
- reviewer 可以复用同 tree 的证据，但最终收口仍需要绑定 final tree 的新鲜验证。

## 后果

- bounded 工作减少重复文档和 Prompt 交接，复杂/R2 工作继续保留强审计。
- 新 schema/CLI 要求 verification 使用 profile+command ID、close 带 profile；runner 默认 quiet，可显式 show-output。close 失败必须回滚目标并保留 run state。
- 新旧项目在试运行与推广决定前保持 advisory；推广获批后既有项目仍需显式启用 required。历史 v2 制品和 013 发行证据不迁移、不改写。
- 确定性 fixture 只能证明接口行为；真实 Agent A/B 尚未运行，不得宣称目标已经达成。local consistency 也不是对抗性防篡改证明。

## SoT 投射

- `docs/sot/governance/P2T2C_GOVERNANCE.md` 的 RULE-GOV-001、003、014、015、016。

# ADR-015：最小上下文与等价执行提效

Status: Accepted
Date: 2026-08-27
Change Pack: `docs/change_packs/CPK-20260826-context-execution-efficiency.md`
Truth Patch: `docs/sot/governance/P2T2C_GOVERNANCE.md`
Truth Patch SHA-256: `93c03bd0722bf74fde374bda0cf55e5f2d8a2b0ac3e0e3b7655612f58bdeb408`

## 背景与决定

0.14 建立了正确的机器证据与自适应治理，但默认入口仍重复加载配置/manifest/阶段说明，CR 又内嵌整份 ledger；checker、close 和双语 smoke 还重复解析或执行等价工作。

0.14.1 将运行信息分为 Hot/Warm/Cold，提供确定性有界 context/status/evidence 视图，以 receipt v2 引用内容寻址 evidence sidecar，并把失败输出保存在临时冷日志。执行引擎使用一次索引、严格限定的历史缓存、coverage-aware batch verify、一次 close prepare 和分 suite smoke。所有复用都绑定 artifact/config/tool/schema/Git/final-tree digest。

方法 profile 保持 `p2t2c-adaptive-v2`，因为本次不改变风险、Gate、Agent 派生、模型档位、审查角色或修复上限。0.14.1-C 的 Agent 策略实验明确不实施。

## 后果与威胁边界

- 常规 Agent 不再读取 raw config/ledger/历史 CR，失败详情通过安全路径与有界 tail 按需取得。
- 历史 inline receipt v1 与完整 project config 原样有效；升级不改写历史制品或项目拥有配置。
- 防护覆盖 sidecar/cache substitution、symlink/hardlink/TOCTOU、部分事务、并发、fallback 降级、陈旧 capsule 和终端注入。
- 信任仍是 `local_consistency`；不能抵抗代码、工具、checksum 与证据同时被对手篡改，也不替代 CI 签名或远程证明。
- SIGKILL 最多留下未引用的内容寻址 orphan；旧 target 不会引用错误 sidecar，下一次受锁 close 可安全清理。

## SoT 投射

- RULE-GOV-017 与 RULE-GOV-018。

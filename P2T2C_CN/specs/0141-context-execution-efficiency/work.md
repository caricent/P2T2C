---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260826-context-execution-efficiency.md
---

# Work 014.1：上下文与执行引擎提效

## 接口与数据流

- Hot/Warm/Cold：`p2t2c context|status|evidence summary` 只返回有界聚合与精确定位；原始 ledger/output/历史证据按需冷读。
- Close：冻结 ledger -> receipt v2 + 内容寻址 sidecar candidates -> 离线 pair 校验 -> sidecar 安装 -> target 原子切换 -> 普通 checker -> 成功清理；失败双目标回滚并保留 run。
- Verify：一次 effective-config 解析生成 command plan；同 argv 的 `covers` 去重，只有只读同组命令可并行，每个结果仍绑定 final tree。
- Checker：一次仓库索引；历史 HEAD-clean closed proof 可内容寻址缓存；active/pre-close/global safety 不缓存。

## 任务 DAG 与独占范围

| ID | 范围 | 前置 | 验收 |
|---|---|---|---|
| W1 | context CLI、defaults/manifest、三阶段 Skill、兼容 Prompt、文档/schema | Truth Patch | hot capsule 有界、双语契约一致 |
| W2 | evidence/checker/run/verify/close、sidecar/cache/failure logs | Truth Patch | 旧 v1 兼容且新攻击 fixtures 通过 |
| W3 | smoke suites、0.14.0 fixture、install/upgrade、version/checksum/release | W1/W2 wires | 双语并行迁移与 final all |

单一集成 controller 为 `root-controller`；各批次独立审查后才集成。0.14.1-C 不在任何批次。

## 验证、审查与恢复

1. 先记录新 wire 缺失的 RED，再按 ownership 并行实施并运行局部 GREEN/mutation。
2. W1/W2/W3 各自 batch review；集成后 global + specialist review。
3. 重新生成 checksum，在同一 final tree 运行 full 与 governance；发布只接受 `smoke --suite all`。
4. 从 CPK/work、Git diff、`p2t2c status` 与 `p2t2c evidence summary` 恢复；不要默认加载 raw ledger 或 CR sidecar。

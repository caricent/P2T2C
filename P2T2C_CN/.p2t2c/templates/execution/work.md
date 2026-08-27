---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-YYYYMMDD-short-title.md
---

# Work {NNN}：{功能名称}

仅用于 `execution_shape: architectural`。本文件组织执行，不重复 CPK，也不定义业务规则。

## 接口与数据流

- 受影响接口、schema 或 I/O：
- 组件间数据流：
- 兼容与迁移边界：

## 任务 DAG 与所有权

| 唯一 batch ID | 前置 | 独占文件/模块 | Implementer 档位 | 验收 |
|---|---|---|---|---|
| B1 | None | `{path}` | 快速 / 标准 / 最强 |  |

- 单一集成 controller：
- CPK implementer 与 contract digest：
- CPK `ownership_batches`（与本表 ID 完全一致）：
- `legacy_startup_evidence` 及旧三件套依据：
- 同形微任务合并：
- 禁止 implementer/reviewer 递归 fan-out。

## 集成顺序

1. 
2. 

## 验证与审查

- 每个 changed path 命中的强制 path mapping、mapping digest 与 command IDs：
- fast / impacted 内循环：
- final-tree full 完整命令集（R2/multi-Agent）：
- 同一 final-tree governance 完整命令集（`governance_change: true`）：
- `batch` review：
- `global` review：
- `specialist` review（`specialist_review_required: true`）：
- `re_review` 回链原 batch/scope：
- reviewer 与 implementer 不同，Critical/Important/Minor 全为 0：

## 漂移与恢复

- execution shape/risk 升级条件：
- 文件式 brief/diff/evidence 路径：
- 上下文压缩后的恢复点：
- Execution Doc Drift 回填：
- Gate B event/decision/ref/Truth Patch ref（如 resolved）：
- receipt trust：`local_consistency`，非对抗性本地一致性
- receipt `methodology_enforcement` / `evidence_completeness` / `evidence_warnings` 与 matched profiles/paths：
- atomic close 回滚/保留 run state：

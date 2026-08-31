---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260826-adaptive-v2.md
---

# Work 014：分层自治与机器证据

本文件是将随 v0.14 Truth Patch 原子生效的 architectural 执行索引。相邻 `spec.md`、`plan.md`、`tasks.md` 是本 R2 变更在 v0.13 下启动时创建的审计证据，不是新产物矩阵要求。

## 接口与数据流

- CPK v3 还以 governance 文件 SHA-256、W1/W2/W3 ownership 与 legacy=true 绑定本次 Truth/协作/启动例外；任何 Truth edit 后刷新 digest。
- recorder 写入 exploration、TDD、route/isolation/repair/Gate B 与 batch/global/specialist/re_review；close 原子投射 local-consistency receipt。
- project config 定义 verification profiles/path mapping；所有发行消费者共同读取 `.p2t2c/managed-files.txt`，manifest 只保存指针。

## 任务 DAG 与所有权

| 唯一 ID | 内容 | 前置 | 独占范围 | 验收 |
|---|---|---|---|---|
| W1 | 治理与双语文档 | None | Truth、ADR、CPK、Prompt、Skill、模板、eval | 双语稳定枚举与路径一致 |
| W2 | 机器证据 | CPK 契约 | recorder、close、checker、负向 fixture | 本地陈旧 SHA/digest/契约不一致被拒绝 |
| W3 | 发行基础设施 | CPK 契约 | managed-files、配置、安装升级、migration、smoke | 单一清单驱动全消费者 |

- 单一集成 controller：根任务 Agent。
- 写批次路径不重叠；同形双语更新在各自 ownership 内批处理。
- implementer/reviewer 不递归 fan-out。
- W1、W2、W3 分别必须有独立 `batch` review；最终集成是 controller checkpoint，不是新的 ownership batch，并需要 `global` + `specialist`。

## 集成顺序

1. 锁定 CPK/work/CR schema、配置 wire shape 和新增受管路径。
2. 合并 W1-W3，运行 schema/结构检查并修复接口差异。
3. 重新生成 checksum，运行双语、安装、升级、回滚、本地一致性负向 fixture 和最终 full/governance。
4. 独立 global/specialist 审查，原 finding 修复后用 `re_review`，再原子投射证据并自动创建 R2 CR。

## 验证与审查

- 同一 final tree 独立完成 `verification.full` 全集与 `verification.governance` 全集。
- W1、W2、W3 各有独立 `batch` review；最终集成用 `global`，安装/升级/证据安全用 `specialist`，修复复审用 `re_review` 并回链原 scope/batch。
- reviewer 与 `root-controller` 不同；所有必需审查的 Critical/Important/Minor 为 0。
- receipt 使用 `evidence_trust: local_consistency`，不声称对抗防篡改。
- 每个 changed path 必须命中 mapping；receipt 投射 mapping/matched paths、`methodology_enforcement`/`evidence_completeness`/`evidence_warnings`、baseline/risk ref。
- close 原子投射并运行普通 checker；失败回滚目标并保留 run state。

## 漂移与恢复

- 已处于 architectural/R2，不允许降级；新未决定语义返回 Gate A。
- 从 CPK、work、Git diff、`.p2t2c/runs/<work-id>/events.jsonl` 和 Agent 状态恢复。
- Execution Doc Drift 自动回填本文件；接受实现并修改 Truth 才触发 Gate B。

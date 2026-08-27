# Plan 014：分层自治与机器证据

Based on: `spec.md`

> v0.13 启动证据；当前实现索引见 `work.md`。

## 实现策略

先更新治理 Truth 与 schema，再并行实现机器证据和发行基础设施，最后在同一 final tree 上运行 full/governance 与独立全局审查。

## 影响范围

| 模块 | 动作 | 责任 |
|---|---|---|
| Truth、入口、Prompt、Skill、模板 | 应用 adaptive-v2 | 治理文档批次 |
| recorder、close、checker、fixture | 机器证据与 SHA 绑定 | 证据工具批次 |
| manifest、配置、安装升级、migration | 单一受管清单与发行 | 基础设施批次 |

## 风险与处理

| 风险 | 处理 |
|---|---|
| 旧项目被破坏 | 缺失新配置保持 advisory；历史 v2 制品不迁移 |
| Truth/契约/路径证据陈旧 | Truth SHA-256、contract/path-mapping digest、matched paths 与 final tree 硬校验 |
| 并行冲突 | 独占文件所有权、单一 controller 集成、禁止递归 fan-out |
| 双语/清单分叉 | 稳定枚举检查与共同消费 `.p2t2c/managed-files.txt` |

## 验证策略

- Deterministic：schema、产物矩阵、Gate A/B、历史兼容和本地一致性负向输入；不声称对抗安全。
- Delivery：安装、升级、回滚、checksum 与 managed-file parity。
- Atomic closure：故障注入投射后 checker/cleanup，验证目标回滚且 run state 保留。
- Behavior eval：定义 control/treatment 和评分；只有真实运行达标并经人类决定才推广 required。

## 隔离、协作与审查

- 宿主管理工作区；写所有权不重叠。
- ownership batch 审查 + final-tree 全局审查；发行与证据安全专项核对。

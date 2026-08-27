# P2T2C Adaptive 风险路由工作流

P2T2C 表示 **Proposal-to-Truth-to-Code**。v0.14 在保留 Truth、R0/R1/R2、Gate A/B 和最终新鲜验证的同时，让流程仪式随任务形态缩放。

```text
准入 + 路由 -> 计划 + 执行 -> 验证 + 修复 + 漂移 + 收口
```

AI 操作入口是 `P2T2C_AGENTS.md`。

## 风险与执行形态

风险决定 AI 能否改 Truth：R0 不改变业务行为，R1 实现既有 Truth，R2 改变 Truth/契约/数据/安全/权限。正交的 execution shape 决定执行与文档强度：`spike` 是可丢弃探索，`bounded` 是单批次工作，`architectural` 需要 DAG、所有权和集成。

| 场景 | v0.14 持久产物 |
|---|---|
| R0 | 默认无文档；审计模式或剩余风险时自动极简 CR |
| bounded R1 | 单一 CPK v3，内含 closure evidence |
| architectural R1 | CPK v3 + 单一 `work.md` |
| bounded R2 | 完整 CPK v3 + Truth Patch + 自动 CR |
| architectural R2 | 完整 CPK v3 + Truth Patch + `work.md` + 自动 CR |

SP 可选。新 bounded 工作拒绝旧三件套；只有 architectural + `legacy_startup_evidence: true` 保留真实旧流程启动证据。CPK 用唯一 ownership IDs，并用 Truth Patch SHA-256 绑定单一 SoT 文件。

## 机器证据

执行命令、TDD exemption、route、isolation、repair、Gate B 和独立审查记录在 gitignored 的 per-work JSONL ledger 中，并绑定 tree SHA 与 CPK contract digest。收口时把必要 receipt 投射到 R1 CPK 或 R2/R0 CR，验证成功后清理 ledger。Markdown 中手写 `Pass` 或审查声明不再被当作执行证据。

receipt 的 `evidence_trust: local_consistency` 只说明本地非对抗一致性；它不是签名、远程证明或针对可同时篡改工具与 ledger 的安全边界。

每个 changed path 必须命中 path mapping 并解析配置的 command ID。R2/multi-Agent 强制 full，governance change 额外 governance；缺 mapping 是核心硬失败。

示例：

```bash
bash .p2t2c/bin/p2t2c_run.sh --work-id CPK-... --event-type verification --verification-profile impacted --command-id p2t2c-check
bash .p2t2c/bin/p2t2c_close.sh --work-id CPK-... --verification-profile impacted
```

runner 默认 quiet，只写摘要/digest；调试时显式加 `--show-output`，不能把聊天输出当作证据。verification 命令只能由项目配置的 profile + command ID 解析，不接受任意尾随命令。

## 质量护栏

- bounded R1 生产代码做一次独立综合审查；architectural R1/R2 做 batch + global 审查，适用时增加 specialist。reviewer 与 implementer 身份不同，Critical/Important/Minor 必须全为 0。
- 两轮修复均恢复原 implementer，只复审 finding 与 fix diff；第三轮停线。
- read-only 可并行；写并行要求无所有权重叠、明确基线和单一 controller。
- implementer/reviewer 不得递归派生 Agent。
- 明确违反 Truth 的实现由 Agent 先修正并重验；只有接受实现并修改 Truth 才触发 Gate B。

## 首次安装

```bash
cd /path/to/P2T2C_CN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

v0.14 advisory 仍硬门控核心证据。方法缺口投射为 `evidence_warnings`，`evidence_completeness` 不完整，不能冒充 complete。真实 A/B 达标并经人类决定后才推广 required。

## 升级

```bash
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_CN
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_CN
```

安装与升级只更新未被本地修改的受管工作流外壳，保留项目拥有的 Truth、ADR、SP、CPK、spec/work、代码、测试和历史 CR。

## 目录

| 路径 | 职责 |
|---|---|
| `P2T2C_AGENTS.md` | AI 操作入口 |
| `docs/sot/**` | 当前业务 Truth |
| `docs/adr/**` | 需长期解释的决策原因 |
| `docs/change_packs/**` | R1/R2 CPK v3 |
| `specs/**/work.md` | architectural 执行索引 |
| `docs/closure/**` | 自动生成的 R2 / 条件性 R0 CR |
| `.p2t2c/runs/**` | gitignored 临时机器证据 |
| `.p2t2c/**` | Prompt、Skill、模板、脚本和升级元数据 |

# P2T2C_AGENTS.md — P2T2C AI 操作入口

这是本发行根唯一的 P2T2C AI 操作入口。

P2T2C 表示 **Proposal-to-Truth-to-Code**。默认行为是持续推进；只有出现未决定的语义、Truth 冲突、危险操作、外部权限、重复验证失败或 Truth Drift 时暂停。

```text
意图准入 -> 风险路由与 Truth -> 工作批次执行 -> 验证与自主修复 -> 漂移检查与收口
```

## 1. 基础读取

开始任务时读取：

1. `P2T2C_AGENTS.md`
2. `.p2t2c/project_config.yaml`；缺失时读取示例
3. `docs/sot/manifest.yaml`
4. 与当前意图直接相关的 SoT、ADR、代码和测试

默认不读 `docs/reference/**` 和治理历史。只有历史审计、迁移或冲突排查时读取。

## 2. 五阶段 Prompt

| 阶段 | Prompt | 主要输出 |
|---|---|---|
| 意图准入 | `.p2t2c/prompts/01_intent_admission_prompt.md` | 清晰、无冲突的意图摘要 |
| 风险路由与 Truth | `.p2t2c/prompts/02_risk_routing_and_truth_prompt.md` | R0，或持久化 `CPK-*` |
| 工作批次执行 | `.p2t2c/prompts/03_execute_work_batch_prompt.md` | 代码；R1/R2 的精简三件套 |
| 验证与自主修复 | `.p2t2c/prompts/04_verify_and_repair_prompt.md` | 实际验证证据 |
| 漂移检查与收口 | `.p2t2c/prompts/05_drift_and_closure_prompt.md` | `CR-*` 或 Gate B |

## 3. 执行方法层

P2T2C 是风险、Truth、关卡和收口的控制层。可选方法层只说明已获准工作批次如何执行，绝不定义业务行为或覆盖 Truth。

风险路由后按需读取 `.p2t2c/skills/` 中的方法：

- `design-refinement`：存在会影响结果的意图歧义时。
- `risk-aware-tdd`：可自动化的 R1/R2 行为。
- `root-cause-debugging`：修复验证失败之前。
- `independent-review`：收口 R1 生产代码或任何 R2 变更之前。
- `workspace-isolation`：R2、并行或明确要求隔离的工作之前。

存在时使用 `methodology` 配置。缺少配置的历史项目处于兼容性 advisory 模式；不得仅因 CPK、spec 或 CR 早于本方法层而使其失败。

## 4. 风险路由

- `R0`：重构、测试、文档、CI 调整，或恢复 Truth 已定义的行为。不创建 CPK 和执行文档。
- `R1`：实现现有 Truth 已覆盖的行为。创建紧凑 `docs/change_packs/CPK-*.md`，不得修改 Truth。
- `R2`：修改 Truth、ADR、外部契约、持久数据语义、安全、隐私、权限或不可逆操作。创建完整 CPK。

R1/R2 在 `specs/{NNN-feature}/` 中使用精简 `spec.md`、`plan.md`、`tasks.md`。一个工作批次可以包含多个相关 Task。

所有完成的 R0/R1/R2 工作都必须生成 `docs/closure/CR-*.md`。

## 5. 人类关卡

Gate A 只控制尚未决定的 R2 语义：

- 当前用户指令已经明确决定完整语义时，记录 `gate_a: satisfied`，不要重复确认。
- 尚未决定时记录 `gate_a: pending`，提供明确选项并暂停。
- `gate_a: pending` 时不得应用 Truth Patch 或进入执行阶段。

Gate B 只在 Truth Drift 时触发：

1. 修正实现，使其符合 Truth。
2. 接受实现并更新 Truth。
3. 创建或更新意图、SP、ADR 后重新评估。

## 6. Truth 边界与来源优先级

业务规则只能放在 `docs/sot/**`。ADR 解释决策原因。CPK、spec、plan、tasks、测试、代码注释和聊天不能成为业务规则的唯一来源。

来源优先级：

1. 当前任务中人类明确确认的决策
2. 已接受 SP、ADR
3. 当前 `docs/sot/**`
4. 当前 CPK 与执行文档
5. 当前代码与测试
6. `docs/reference/**`

低优先级来源与高优先级来源冲突时暂停。

## 7. 验证与暂停边界

运行项目适用的 Build、Test、Lint、Typecheck 和 Governance 检查。修复失败前先复现、调查根因、对比可工作模式并写出一个可验证假设；同一失败最多两轮修复，环境性失败允许一次原样重试。没有新鲜验证证据不得声明完成。

仅在以下情况暂停：

- 存在会改变结果的关键歧义或 Truth/ADR 冲突。
- 需要尚未决定的业务、架构、安全、权限或数据语义。
- 需要危险操作或外部权限。
- 同一验证失败超过自主修复上限。
- 代码改变、扩展或违反 Truth。

## 8. 安装与升级安全

安装和升级只更新 P2T2C 工作流外壳，不得重写项目拥有的 Truth、ADR、SP、CPK 实例、spec、代码、测试、数据库文件或历史 CR。

应用前必须先运行 dry-run：

```bash
make p2t2c-install-dry-run TARGET=/path/to/project
cd /path/to/project
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_CN
```

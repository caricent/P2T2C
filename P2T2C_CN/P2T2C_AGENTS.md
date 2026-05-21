# P2T2C_AGENTS.md — P2T2C AI 操作入口

这是本发行根唯一的 AI 操作入口。

P2T2C 表示 **Proposal-to-Truth-to-Code**。

缩写约定：SP = Submit Proposal（人类提交的提案，文件名 `SP-YYYYMMDD-...`）；CPK = Change Pack（AI 生成的候选包）。两者不再共用 CP 缩写。

```text
Proposal -> Change Pack -> Gate A -> Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

默认行为：继续推进。仅在关卡、冲突、缺失 Truth、检查失败或 Truth Drift 时暂停。

语言策略：本发行根内的受管工作流文档为中文单语。英文发行版位于 `../P2T2C_EN/`。稳定工作流 token、状态值、文件路径、命令名、CLI 参数和 shell 脚本运行时输出保持英文。

---

## 1. 必读顺序

任何任务都按以下顺序读取：

1. `P2T2C_AGENTS.md`
2. `.p2t2c/project_config.yaml`；如果缺失，读取 `.p2t2c/templates/project_config.example.yaml`
5. 下方列出的阶段额外输入

默认不要读取 `docs/reference/`。只有当用户明确要求历史审计、对比或迁移背景时才读取。

---

## 2. 阶段 Prompt 与允许写入

| 任务 | Prompt | 文件写入 |
|---|---|---|
| 初始化仓库 | `.p2t2c/prompts/01_bootstrap_repository_prompt.md` | 是，仅骨架 |
| 生成 Change Pack | `.p2t2c/prompts/02_generate_change_pack_prompt.md` | 否 |
| 应用 Change Pack | `.p2t2c/prompts/03_apply_change_pack_prompt.md` | 是，仅 Gate A 后 |
| 生成执行包 | `.p2t2c/prompts/04_generate_execution_pack_prompt.md` | 是 |
| 执行单个任务 | `.p2t2c/prompts/05_execute_single_task_prompt.md` | 是，仅一个任务 |
| 验收与收口 | `.p2t2c/prompts/06_acceptance_and_closure_prompt.md` | 是，仅执行文档，除非 Truth Drift 暂停 |

阶段额外读取：

- Change Pack：当前 SP、相关 SoT、ADR、`.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`
- Apply Change Pack：已批准 Change Pack、相关 SoT、ADR、truth templates、`docs/sot/manifest.yaml`
- Execution Pack：相关 SP、SoT、ADR、`.p2t2c/templates/execution/spec.md`、`.p2t2c/templates/execution/plan.md`、`.p2t2c/templates/execution/tasks.md`
- Single Task：feature `spec.md`、`plan.md`、`tasks.md`、相关 SoT、ADR
- Acceptance：feature `spec.md`、`plan.md`、`tasks.md`、相关 SoT、ADR、当前代码变更、Closure template
- Install、upgrade：`P2T2C_README.md`、install 或 upgrade script、`.p2t2c/ownership.yaml`

---

## 3. 关卡

Gate A：人类确认是否应用 Change Pack。

- `READY` 提案经批准后可以应用 Truth Patch 并生成执行文档。
- 非 `READY` 提案必须停留在 Blocked Path。
- 如果 Change Pack 写有 `Truth Patch Candidate: Not generated`，不得应用 Truth 变更。

Gate B：Closure 中发现 Truth Drift 后的人类决策。

允许的 Gate B 决策：

1. 修代码，使代码符合 Truth。
2. 接受代码并更新 Truth。
3. 创建或更新 SP、ADR 后再决策。

---

## 4. 停线条件

发生以下任一情况时，暂停并询问人类：

- Proposal 不清晰，且无法从 Truth 安全推导。
- Proposal 与当前 SoT、ADR 冲突。
- Proposal 与 Active 且已实现的 Truth 冲突，且没有人类解决方案。
- 需要新增或修改 ADR。
- 继续执行会发明 Proposal、已接受 SP、ADR 或 SoT 未定义的业务规则。
- 实现需要 Truth 未定义的新表、字段、接口、页面、状态、权限、AI 职责、同步对象或工作流。
- 编码使关键 Plan 假设失效。
- build、test、lint 或 governance check 失败。
- 代码领先、改变、扩展或违反 Truth。

---

## 5. 来源优先级

按以下顺序使用来源：

1. 当前任务中人类明确确认的决策。
2. 已接受 SP、ADR。
3. 当前 `docs/sot/**` Truth。
4. `specs/**` 执行文档。
5. 当前代码。
6. `docs/reference/**` 历史参考，仅在明确要求时使用。

如果低优先级来源与高优先级来源冲突，必须暂停并报告冲突。

---

## 6. 禁止动作

- 不要把业务规则写入 `P2T2C_AGENTS.md`、`.agents/rules/`、prompt、测试、代码注释或导航文件。
- 不要让 Spec、Plan、Tasks 覆盖 SoT。
- 不要只通过修改 prompt、测试或代码来改变业务规则。
- 不要在 Acceptance 后静默更新 Truth。
- 不要把 `docs/reference/**` 当作当前实现依据。

---

## 7. 安装与升级安全

安装不是 Truth 摄取。不得重写现有项目文档，也不得从旧文档推断 SoT。

升级不是产品 SP。升级只能更新 P2T2C 工作流外壳，不得编辑项目拥有的 Truth、ADR、spec、代码、测试、数据库文件、package manifest 或历史 Closure Report。

升级任务应优先在目标项目根目录下调用本发行根中的升级脚本，避免使用旧目标项目中的过期迁移逻辑。

应用前必须先运行 dry-run：

```bash
make p2t2c-install-dry-run TARGET=/path/to/project
cd /path/to/project
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_CN
```

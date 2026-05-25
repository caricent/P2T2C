# P2T2C 工作流模板

P2T2C 表示 **Proposal-to-Truth-to-Code**。

缩写约定：SP = Submit Proposal（人类提交的提案，文件名 `SP-YYYYMMDD-...`）；CPK = Change Pack（AI 生成的候选包）。两者不再共用 CP 缩写。

P2T2C 帮助开发者与 AI 协作开发软件，同时避免需求、权威 Truth、实施计划、代码变更和验收结果相互脱节。它让 AI 保持推进能力，但防止 AI 在缺少确认或 Truth 支撑时自行改变业务规则。

```text
Proposal -> Change Pack -> 需要 SoT/ADR 变更时进入 Gate A -> 如需要则 Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

默认行为：AI 持续推进。只有在明确关卡、冲突、缺失 Truth、验收失败或 Truth Drift 时暂停。

语言策略：本发行根内的受管工作流文档为中文单语。英文发行版位于 `../P2T2C_EN/`。稳定工作流 token、路径、命令、状态值、CLI 参数和 shell 运行时输出保持英文。

AI agent 的唯一操作入口是：

```text
P2T2C_AGENTS.md
```

---

## 1. 首次设置

从 P2T2C 中文发行根安装到目标项目中：

```bash
cd /path/to/P2T2C_CN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

进入目标项目后，创建项目配置：

```bash
cd /path/to/project
cp .p2t2c/templates/project_config.example.yaml .p2t2c/project_config.yaml
```

编辑 `.p2t2c/project_config.yaml`，填写项目名称、描述、语言和技术栈。

然后运行：

```bash
bash .p2t2c/bin/check_p2t2c.sh
```

预期结果：

```text
P2T2C checks passed.
```

---

## 2. 人类工作流

1. 在 `docs/submit_proposals/SP-YYYYMMDD-...md` 编写或让 AI 草拟 Submit Proposal。
2. 让 AI 基于 SP 生成 Change Pack。
3. 如果 CPK 不需要变更 SoT 或 ADR，直接继续生成执行文档。
4. 如果 CPK 需要变更 SoT 或 ADR，通过 AI 给出的选项审查 Gate A：批准并应用 Truth Patch，或修订、拒绝、拆分、解决提案、处理 ADR。
5. 让 AI 生成 `spec.md`、`plan.md` 和 `tasks.md`。
6. 让 AI 一次执行一个 task。
7. 仅在 Closure Report 报告 Truth Drift 时审查它。

只有当 Closure Decision 为以下值时才需要 Gate B：

```text
HUMAN_TRUTH_DECISION_REQUIRED
```

---

## 3. 安装到另一个项目

仅对从未使用过 P2T2C 的项目使用此流程。

先运行 dry-run：

```bash
make p2t2c-install-dry-run TARGET=/path/to/project
```

审查输出后：

```bash
make p2t2c-install TARGET=/path/to/project
```

安装只复制缺失的工作流外壳文件。它不会覆盖现有文件、重写业务文档、推断 Truth 或编辑源代码。

---

## 4. 升级现有 P2T2C 项目

在目标项目根目录运行升级命令，但调用本发行根中的升级脚本。

先运行 dry-run：

```bash
cd /path/to/project
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_CN
```

审查输出后：

```bash
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_CN
```

回滚已应用的升级：

```bash
make p2t2c-rollback UPGRADE=.p2t2c/upgrade/{upgrade-id}
```

如果目标项目自己维护了 Makefile alias，也可以继续使用本地 alias；新安装不会创建根级 Makefile。

如果文件自上次 lock 后未被本地修改，升级脚本可以更新 workflow、template、prompt、governance 和 metadata 文件。升级脚本不得修改项目拥有的 Truth、ADR、spec、源代码、测试、数据库文件或历史 Closure Report。

---

## 5. 目录说明

安装到项目后，P2T2C 在根目录保留 `P2T2C_README.md` 和 `P2T2C_AGENTS.md` 作为入口，并只暴露 `docs/` 和 `specs/` 作为日常工作面；prompt、模板、脚本、校验和、license 和迁移说明都收敛到隐藏的 `.p2t2c/`。

| 路径 | 职责 |
|---|---|
| `P2T2C_README.md` | 人类入口 |
| `P2T2C_AGENTS.md` | AI 操作入口 |
| `.p2t2c/P2T2C_LICENSE.md` | 单独复制发行根时保留的 MIT license notice |
| `.p2t2c/templates/project_config.example.yaml` | 项目配置模板 |
| `.p2t2c/CHECKSUMS.sha256` | release 文件校验和 |
| `.p2t2c/` | 模板元数据、归属和 lock 状态 |
| `.p2t2c/bin/` | 检查、安装、升级、回滚 |
| `docs/submit_proposals/` | 提案模板和 SP |
| `docs/adr/` | 已接受的架构或策略决策记录 |
| `docs/sot/` | 当前项目 Truth |
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | P2T2C 权威治理 Truth |
| `docs/closure/` | Closure Reports |
| `docs/reference/` | 仅历史参考；默认不读取 |
| `.p2t2c/templates/execution/` | Spec、Plan、Tasks 模板 |
| `specs/` | 功能执行文档 |
| `.p2t2c/templates/` | 可复用 P2T2C 产物模板 |
| `.p2t2c/prompts/` | AI agent 阶段 prompt |
| `.p2t2c/migrations/` | 模板迁移说明 |

业务规则属于 `docs/sot/`。ADR 解释决策原因。Spec、Plan、Tasks、prompt、测试和代码不能成为业务规则的唯一来源。

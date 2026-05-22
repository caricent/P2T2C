# Rule Block 模板

Truth 规则分两层记录，以降低 AI 每次任务的阅读量（见 RULE-GOV-012）：

- **Active 层**：写在 `docs/sot/**` 的主 SoT 文件里，只保留执行期必需的字段。
- **History 层**：lifecycle 元数据（`Source`、`Supersedes`、`Superseded by`、`Migration required`、`Downstream projections`）和已 `Superseded`/`Deprecated` 的整条规则，写在同目录的 `*_HISTORY.md` 文件里。`make check` 把两层合起来做完整性校验，AI 默认只读 Active 层。

---

## Active 层 Rule Block（写入主 SoT 文件）

```text
### RULE-{AREA}-{NNN}: {规则名称}

Status: Active
Phases: {一个或多个 phase token，逗号分隔；见下方 Allowed phases}

规则:

{一条清晰、可执行、可验证的规则。}

验证:

- {自动化测试、手动验收、治理检查或 Code Review checklist}

停线条件:

- {什么情况下必须暂停找人确认}
```

Allowed phases（稳定 token，与 manifest `phases` 列表一致）:

- `bootstrap` — 初始化仓库
- `change_pack` — 生成 Change Pack
- `apply_change_pack` — 应用 Change Pack / Truth Patch
- `execution_pack` — 生成执行包（spec/plan/tasks）
- `single_task` — 执行单个任务
- `acceptance` — 验收与收口
- `install_upgrade` — 安装与升级
- `all` — 跨所有阶段的工作流根规则（如单一路径、Truth 边界）

`Phases` 必须至少含一个 token。AI 在某阶段只读取 `Phases` 含该阶段（或 `all`）的规则；新增规则只需声明所属阶段，按需读取清单由 `check_p2t2c.sh` 自动生成，无需手工维护。

---

## History 层条目（写入 `*_HISTORY.md`）

每条 Active 规则在 History 文件里有一条对应的 lifecycle 记录；已被取代的规则的全文也只留在 History 文件里。

```text
### RULE-{AREA}-{NNN}

Status: Active | Superseded | Deprecated
Source: {SP、ADR 或 human decision}
Supersedes: {RULE-ID or None}
Superseded by: {RULE-ID or None}
Migration required: Yes 或 No
理由: {为什么存在这条规则。}
下游投射:
- Spec: {哪些 spec 应引用}
- Tests: {哪些测试应覆盖}
- Code: {哪些模块应实现}
```

约束（由 RULE-GOV-009 校验，扫描 Active + History 合集）:

- `RULE-{AREA}-{NNN}` 标识在整个 `docs/sot/**`（含 History）内唯一。
- lifecycle 链双向闭合：`RULE-A` 的 `Superseded by: RULE-B` 必须对应 `RULE-B` 的 `Supersedes: RULE-A`。
- `Supersedes`/`Superseded by` 引用的每个标识都必须能在 `docs/sot/**` 找到真实条目。
- 被 `Superseded by` 指向的规则不得为 `Status: Active`。

代码锚点 (RULE-GOV-010):

- 实现代码携带仅含指针的注释，如 `Implements: RULE-{AREA}-{NNN}`。
- 锚点只记录指针；规则文本留在 SoT，绝不写入代码注释。

# P2T2C 风险路由工作流

P2T2C 表示 **Proposal-to-Truth-to-Code**。它让 AI 默认持续推进，同时把人类决策集中在尚未决定的语义和 Truth Drift 上。

```text
意图准入
  -> 风险路由与 Truth
  -> 工作批次执行
  -> 验证与自主修复
  -> 漂移检查与收口
```

AI 操作入口是 `P2T2C_AGENTS.md`。

## 风险等级

| 等级 | 适用范围 | 持久化产物 |
|---|---|---|
| R0 | 重构、测试、文档、CI、恢复既有行为 | `CR-*` |
| R1 | 实现现有 Truth 已覆盖的行为 | `CPK-*`、精简三件套、`CR-*` |
| R2 | 改变 Truth、ADR、外部契约、数据语义、安全、权限或不可逆操作 | 完整 `CPK-*`、Truth Patch、精简三件套、`CR-*` |

`SP-*` 是可选意图输入，不再是每个任务的必需产物。R1/R2 的 CPK 放在 `docs/change_packs/`；执行文档放在 `specs/{NNN-feature}/`；所有完成工作都在 `docs/closure/` 生成 CR。

## 人类关卡

- Gate A：仅用于尚未决定的 R2 语义。用户当前指令已经明确决定时，不重复批准。
- Gate B：仅在实现改变、扩展或违反 Truth 时触发。

首次验证失败不会立即停线。AI 会在既定范围内诊断并自主修复；需要新决策、危险操作、外部权限或重复失败时才暂停。

## 首次安装

```bash
cd /path/to/P2T2C_CN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

进入目标项目后，复制并编辑项目配置：

```bash
cp .p2t2c/templates/project_config.example.yaml .p2t2c/project_config.yaml
bash .p2t2c/bin/check_p2t2c.sh
```

## 升级

在目标项目根目录调用新发行根中的脚本：

```bash
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_CN
/path/to/P2T2C_CN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_CN
```

升级脚本只更新未被本地修改的受管工作流文件，保留项目拥有的 Truth、ADR、SP、CPK、spec、代码、测试和历史 CR。

## 目录

| 路径 | 职责 |
|---|---|
| `P2T2C_AGENTS.md` | AI 操作入口 |
| `docs/sot/**` | 当前业务 Truth |
| `docs/adr/**` | 决策原因与后果 |
| `docs/submit_proposals/**` | 可选 SP 输入 |
| `docs/change_packs/**` | R1/R2 CPK |
| `specs/**` | R1/R2 精简执行三件套 |
| `docs/closure/**` | 所有完成工作的 CR |
| `.p2t2c/**` | Prompt、内部模板、脚本和升级元数据 |

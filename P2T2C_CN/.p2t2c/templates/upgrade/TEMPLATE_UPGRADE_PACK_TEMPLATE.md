# 模板升级包 — P2T2C {from-version} -> {to-version}

状态：Draft | Applied | Blocked
来源发行根：`{path or URL}`

## 升级摘要

{本次工作流、模板或治理能力变化。}

## 兼容性

| 项目 | 决策 |
|---|---|
| 升级后的新工作 | 使用升级后的风险路由工作流 |
| 历史 SP、CPK、spec、task、CR | 保持不变 |
| receipt v1/v2 与历史 evidence sidecar | 保持不变；仅 legacy 工作继续使用 |
| 活动 `.p2t2c/runs/**` 与 cache 状态 | 绝不作为发行受管或 rollback 目标 |
| 受管文件 mode | 按 policy 修复；rollback 恢复旧 mode |
| 项目拥有的 Truth、ADR | 不修改 |
| 文档布局 | 普通升级不移动；仅显式 `docs-migrate` 修改 |

## 受管文件动作

| 文件 | 动作 |
|---|---|
| `{path}` | Update / Create / Remove when lock matches |

## 需人工审查

| 文件 | 原因 |
|---|---|
| `{path}` | Local modification / conflict |

## 项目拥有文件不变

升级不得修改项目业务 Truth、ADR 实例、SP 实例、CPK 实例、spec、代码、测试、数据库文件、历史 CR、evidence sidecar、活动 run、cache 状态或 `.p2t2c/project_config.yaml`。

## 验证

```bash
bash .p2t2c/bin/check_p2t2c.sh
./.p2t2c/bin/p2t2c --help
shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
```

## 收口

决策：CLOSE | MANUAL_CONFLICT_RESOLUTION_REQUIRED

```bash
bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/{upgrade-id}
```

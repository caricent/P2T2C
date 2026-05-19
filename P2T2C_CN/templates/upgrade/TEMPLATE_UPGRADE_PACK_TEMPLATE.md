# 模板升级包 — P2T2C {from-version} -> {to-version}

Source release: `{path or URL}`

---

## 升级摘要

governance 能力。}

---

## 兼容性

| Item | Decision |
|---|---|
| New CPs after upgrade | Use upgraded P2T2C workflow |
| Existing specs、tasks | Leave unchanged |
| Historical Closure Reports | Leave unchanged |
| Project-owned Truth、ADR | Do not modify |

| 项目 | 决策 |
|---|---|
| 升级后的新 CP | 使用升级后的 P2T2C 工作流 |
| 现有 specs、tasks | 保持不变 |
| 历史 Closure Reports | 保持不变 |
| 项目拥有的 Truth、ADR | 不修改 |

---

## 待更新文件

| File | Ownership | Action |
|---|---|---|
| `{path}` | core-managed / governance-managed | Update / Create |

---

## 需人工审查文件

| File | Reason |
|---|---|
| `{path}` | Local modification / conflict |

---

## 项目 Truth 不变

升级绝不能修改：

- `docs/sot/product/**`
- `docs/sot/data/**`
- `docs/sot/api/**`
- `docs/sot/client/**`
- `docs/sot/server/**`
- `docs/sot/ai/**`
- `docs/sot/testing/**`
- `docs/adr/**`
- `specs/**`
- `src/**`
- `tests/**`

---

## 验证命令

```bash
make check
```

模板源包可选：

```bash
shasum -a 256 -c CHECKSUMS.sha256
```

---

## 升级收口

决策: CLOSE | MANUAL_CONFLICT_RESOLUTION_REQUIRED

回滚命令：

```bash
make p2t2c-rollback UPGRADE=.p2t2c/upgrade/{upgrade-id}
```

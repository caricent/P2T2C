# Change Packs

`docs/change_packs/` 保存风险等级为 `R1` 或 `R2` 的持久化 Change Pack。

- R0 不创建 CPK。
- R1 创建紧凑 CPK，且不得修改 Truth。
- R2 创建完整 CPK；只有尚未决定的语义才需要 Gate A。

命名：

```text
CPK-YYYYMMDD-short-title.md
```

创建新 CPK 时使用同目录的 `CPK_TEMPLATE.md`。

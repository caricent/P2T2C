# Change Packs

`docs/change_packs/` 保存风险等级为 `R1` 或 `R2` 的持久 Change Pack。新工作使用 `schema_version: 3` 和 `methodology_profile: p2t2c-adaptive-v2`；v0.14 先以 advisory 试运行，真实 A/B 与推广决定前不宣称 required。

- R0 默认不创建 CPK。
- bounded R1 只创建一份 CPK v3；意图、Truth 引用、验收、策略和 closure evidence 都在其中。
- architectural R1 创建 CPK v3，并用 `work_pack` 引用一份 `specs/{feature}/work.md`。
- R2 创建完整 CPK v3 与 Truth Patch；只有尚未决定的语义才需要 Gate A，收口时自动创建对应 CR。
- `spike` 不交付可保留变更；需要交付时先升级 execution shape 并重新路由。

CPK 还声明 Truth ref+SHA-256 digest、唯一 ownership batch IDs 与 legacy startup。bounded/spike ownership=none、legacy=false；architectural 才列 IDs，且只有真实旧流程启动时 legacy=true。spike 不得 close。

R1 收口时，工具将绑定 final tree 和 `contract_digest` 的必要证据投射到 CPK marker。R2 投射到自动 CR。reviewer 与 implementer 不同且必需 review 各级 finding 为 0；receipt 的 `local_consistency` 不是对抗性证明。

v0.14.1 的 CPK marker 只保留 receipt v2，原始 events 由内容寻址 sidecar 保存。恢复工作优先用 `p2t2c status` 与 `p2t2c evidence summary`，不默认读取整个 marker/sidecar。

命名：

```text
CPK-YYYYMMDD-short-title.md
```

创建新 CPK 时使用同目录的 `CPK_TEMPLATE.md`。历史 schema v2 CPK 不迁移、不改写。

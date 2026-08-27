# 收口报告

v0.14 按风险与 execution shape 缩放收口产物：

- R0 默认零文档。只有 `p2t2c.r0.audit_mode: true`，或存在剩余风险且 `closure_on_residual_risk: true` 时，才自动生成极简 CR。
- R1 不单独创建 CR；收口证据自动投射到 CPK v3。
- R2 始终自动生成 `docs/closure/CR-*.md`。CPK `CPK-foo` 映射为 `CR-foo`。

R0 没有 CPK。仅当 audit mode 或剩余风险策略要求时运行：

```bash
bash .p2t2c/bin/p2t2c_close.sh --work-id R0-... --verification-profile impacted --remaining-risk-status recorded --remaining-risk-ref docs/risk/RISK-001.md
```

它自动生成 `docs/closure/CR-*.md`。spike 永不收口；必须先升级 execution shape。

无剩余风险时使用 `--remaining-risk-status none --remaining-risk-ref none`。close 是原子操作：投射或普通 checker 失败时恢复原目标并保留 run state，不生成半收口 CR。

新 CR 使用 schema v3 / machine_bound / local_consistency；手写声明不能替代 receipt。receipt 还投射 gate_a、Truth digest、ownership/legacy、methodology enforcement/completeness/warnings、path-mapping digest/matched profiles/paths、baseline 与 remaining-risk ref。advisory warning 使 completeness 不完整，不能冒充完整完成；核心一致性仍硬门。

v0.14.1 新收口的 marker 只包含 receipt v2；原始 events 在 `docs/closure/evidence/EV-<work-id>-<source_digest>.jsonl`。默认通过 `p2t2c evidence summary --work-id <id> --json` 查看有界摘要，只在审计/诊断时读 sidecar。历史 inline receipt v1 不迁移。

Execution Doc Drift 由 Agent 自动回填 CPK/work。明确违反 Truth 的实现默认修正并重新验证；只有接受实现并修改 Truth 时才触发 Gate B。

历史 CR 不迁移、不改写。

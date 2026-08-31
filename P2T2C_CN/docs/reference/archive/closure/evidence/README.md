# 收口冷证据

`EV-<work-id>-<source_digest>.jsonl` 是 close 生成的内容寻址 events-only sidecar。CPK/CR 只保留 receipt v2，用 `evidence_ref`、`source_digest` 和 `event_count` 绑定本文件。

默认使用：

```bash
.p2t2c/bin/p2t2c evidence summary --work-id <id> --json
```

只在审计或失败诊断时读原始 sidecar。不得改名、覆盖、手工编辑或通过 symlink/hardlink 替换。历史 inline receipt v1 保持原样有效，不需迁移。

`evidence_trust: local_consistency` 不是数字签名或远程证明。

# Closure Cold Evidence

`EV-<work-id>-<source_digest>.jsonl` is a content-addressed events-only sidecar created by close. CPK/CR retains receipt v2 only, binding this file through `evidence_ref`, `source_digest`, and `event_count`.

Use this by default:

```bash
.p2t2c/bin/p2t2c evidence summary --work-id <id> --json
```

Read the raw sidecar only for audit or failure diagnosis. Do not rename, overwrite, hand-edit, or substitute it through a symlink/hardlink. Historical inline receipt v1 remains valid byte-for-byte without migration.

`evidence_trust: local_consistency` is not a digital signature or remote attestation.

---
name: p2t2c-verify-close
description: Aggregate verification, repair, review, drift, and atomic closure while reading bounded evidence summaries by default.
---

# Verification, Repair, and Closure

## Input

1. Run `p2t2c context --phase verify-close --work-id <id> --json`, `p2t2c status --work-id <id> --json`, and `p2t2c evidence summary --work-id <id> --json`.
2. Run profiles required by changed-path mapping. R2/multi-Agent requires full; governance change also requires governance; all bind the same final tree.

## Output

- Diagnose root cause first, restore the original implementer for at most two repairs, and link fixes through scoped `re_review`.
- Complete existing batch/global/specialist review rules with every finding zero.
- Compare Truth/CPK/work and handle drift. Gate B only accepts implementation and changes Truth. Invoke close when complete; never handwrite `Pass`.

## Stop Conditions

Do not claim CLOSE unless status is `closable`; stop for missing required evidence/review, any nonzero finding, a third same-failure repair, unresolved gate, or close rollback. Read raw sidecar/log only for audit or diagnosis.

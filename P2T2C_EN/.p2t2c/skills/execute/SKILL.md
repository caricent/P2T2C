---
name: p2t2c-execute
description: Recover from CPK/work and current status, then execute under Truth, ownership, and risk-aware TDD.
---

# Planning and Execution

## Input

1. Run `p2t2c context --phase execute --work-id <id> --json` and `p2t2c status --work-id <id> --json`.
2. Read the listed Truth, CPK, and applicable work. Do not read raw ledger/CR/sidecar by default.

## Output

- Implement within the CPK contract and Gate A boundary; record RED/GREEN or exemption according to `tdd_policy`.
- Architectural work honors unique ownership batches while preserving user changes, baseline, and one integration controller.
- On failure, read only needed cold output through its log ref and diagnose root cause; do not load all history for debugging.

## Stop Conditions

Return to `admit-route` for new semantics or risk/shape upgrade. Load only the applicable specialist skill for TDD, root cause, or isolation details. Do not change Agent spawning, models, review, or the two-repair rule.

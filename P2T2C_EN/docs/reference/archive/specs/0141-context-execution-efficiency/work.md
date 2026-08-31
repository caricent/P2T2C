---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260826-context-execution-efficiency.md
---

# Work 014.1: Context and Execution-engine Efficiency

## Interfaces and data flow

- Hot/Warm/Cold: `p2t2c context|status|evidence summary` returns only bounded aggregates and exact locators; raw ledger/output/history is cold and read on demand.
- Close: freeze ledger -> receipt v2 + content-addressed sidecar candidates -> offline pair validation -> install sidecar -> atomically switch target -> normal checker -> successful cleanup; failure restores both targets and retains the run.
- Verify: one effective-config parse creates the command plan; equal argv may deduplicate through `covers`, only read-only same-group commands may run in parallel, and every result remains final-tree bound.
- Checker: one repository index; historical HEAD-clean closed proof may use a content-addressed cache; active/pre-close/global safety is never cached.

## Task DAG and exclusive ownership

| ID | Scope | Dependency | Acceptance |
|---|---|---|---|
| W1 | context CLI, defaults/manifest, three phase skills, prompt adapters, docs/schemas | Truth Patch | bounded hot capsule and bilingual contract parity |
| W2 | evidence/checker/run/verify/close, sidecar/cache/failure logs | Truth Patch | old v1 compatibility and new attack fixtures pass |
| W3 | smoke suites, real 0.14.0 fixture, install/upgrade, version/checksum/release | W1/W2 wires | parallel bilingual migration and final all |

The single integration controller is `root-controller`; each batch receives independent review before integration. No batch contains 0.14.1-C.

## Verification, review, and recovery

1. Record RED for missing new wires, implement in parallel by ownership, then run local GREEN/mutation.
2. Review W1/W2/W3 independently; perform global and specialist review after integration.
3. Regenerate checksums and run full plus governance on one final tree; release accepts only `smoke --suite all`.
4. Recover from CPK/work, Git diff, `p2t2c status`, and `p2t2c evidence summary`; do not load raw ledger or CR sidecar by default.

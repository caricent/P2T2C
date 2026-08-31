# Execution Documents

adaptive-v2 creates one execution document only for `execution_shape: architectural`:

```text
specs/{NNN-feature}/
  work.md
```

`work.md` references CPK v3 in front matter and records only interfaces/data flow, task DAG, file ownership, integration order, verification, review, and recovery points. Intent, Truth references, and acceptance remain centered in CPK; business rules still belong only in `docs/sot/**`.

Recover context with `p2t2c context --phase execute --work-id <id> --json` and `p2t2c status --work-id <id> --json`; do not copy raw ledger into work.

- Spike creates no execution doc by default.
- Bounded R1 creates only CPK v3.
- Bounded R2 uses CPK v3, Truth Patch, and automatic CR without work.
- Architectural R1/R2 creates CPK v3 + work.

New bounded work with spec/plan/tasks is invalid. Only architectural CPK with `legacy_startup_evidence: true` may retain a real old-workflow startup trio. The 014 CPK is that transition exception, not an adaptive-v2 example.

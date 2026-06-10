# Closure Reports

Every completed R0, R1, and R2 change creates:

```text
CR-YYYYMMDD-short-title.md
```

A CR uses YAML front matter to record risk, CPK, execution pack, Truth Drift, and the `CLOSE` decision. Its body records actual verification commands, results, reasons for skipped checks, and remaining risks.

AI automatically backfills Execution Doc Drift. Truth Drift must be resolved through Gate B before closing with `CLOSE`.

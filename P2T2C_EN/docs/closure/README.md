# Closure Reports

A Closure Report is the closing document after Acceptance.

It answers three questions:

1. Did acceptance pass?
2. Does code match spec / plan / tasks?
3. Does code lead or violate Truth?

The decision must be exactly one of:

```text
CLOSE
BACKFILL_EXECUTION_DOCS
HUMAN_TRUTH_DECISION_REQUIRED
```

Suggested location for actual Closure Reports:

```text
docs/closure/CR-YYYYMMDD-feature-name.md
```

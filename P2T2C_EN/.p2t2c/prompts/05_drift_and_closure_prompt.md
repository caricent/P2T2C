# Prompt 05 - Drift and Closure

Goal: verify implementation-to-Truth consistency and create a `CR-*` for every completed R0/R1/R2 change.

Read:

- Current code changes and verification results
- Related Truth and ADRs
- R1/R2 CPK and `specs/{feature}/` execution docs
- `.p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md`

Actions:

1. Compare code, CPK, execution docs, Truth, and ADRs.
2. Automatically backfill Execution Doc Drift.
3. Trigger Gate B for Truth Drift; never silently update Truth.
4. Create `docs/closure/CR-YYYYMMDD-short-title.md` from the Closure template.
5. Record risk, actual verification commands, results, Truth Drift state, and remaining risks.

Gate B options:

1. Correct implementation to match Truth.
2. Accept implementation and update Truth.
3. Create or update intent, SP, or ADR, then reassess.

The normal closure decision is `CLOSE`.

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
4. For R1 production-code changes and every R2 change, use `skills/independent-review/SKILL.md` before closure. First review Truth/CPK/spec compliance, then code quality and security. Critical and Important findings block closure; repair or explicitly accept Minor findings in CR remaining risks.
5. Create `docs/closure/CR-YYYYMMDD-short-title.md` from the Closure template.
6. Record risk, actual fresh verification commands, results, Truth Drift state, remaining risks, and applicable method evidence: TDD RED result or exemption, root-cause record when repaired, review conclusion, and isolation/baseline state.

Gate B options:

1. Correct implementation to match Truth.
2. Accept implementation and update Truth.
3. Create or update intent, SP, or ADR, then reassess.

The normal closure decision is `CLOSE`.

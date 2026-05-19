# Prompt 06 — Acceptance and Closure Report

Goal: after all Tasks are complete, run acceptance and generate the Closure Report.

First read `AGENTS.md`, then complete the Required Reading listed there.

Additional reads for this stage:

- Current feature `spec.md``spec.md`
- Current feature `plan.md``plan.md`
- Current feature `tasks.md``tasks.md`
- Related SoT
- Current code changes
- `templates/closure/CLOSURE_REPORT_TEMPLATE.md`

Actions:

1. Run feature-level build / test / lint / governance check.
2. Confirm every task Actual result is filled.
3. Compare code with spec / plan / tasks.
4. Compare code with Truth.
5. Generate the Closure Report.

If build / test / lint / governance check fails, stop and report failure evidence. Do not mark failed acceptance as closed.

Closure Decision must be exactly one of:

```text
CLOSE
BACKFILL_EXECUTION_DOCS
HUMAN_TRUTH_DECISION_REQUIRED
```

If the issue is only Execution Doc Drift, backfill spec / plan / tasks.

If Truth Drift exists, stop and ask the human to choose:

1. Fix code.
2. Update Truth.
3. Create / update CP or ADR before deciding.

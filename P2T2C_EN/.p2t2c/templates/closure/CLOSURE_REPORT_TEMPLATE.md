# Closure Report — {feature name}

Status: Draft | Final
Spec: `specs/{NNN-feature}/spec.md`
Plan: `specs/{NNN-feature}/plan.md`
Tasks: `specs/{NNN-feature}/tasks.md`
Generated at: {YYYY-MM-DD}

> A Closure Report is written after Acceptance to decide whether work can close and whether code leads Truth.
>

---

## 1. Acceptance Summary

| Check | Result | Evidence |
|---|---|---|
| Build | Pass / Fail / NA |  |
| Tests | Pass / Fail / NA |  |
| Lint / Typecheck | Pass / Fail / NA |  |
| Governance check | Pass / Fail / NA | `make check` |
| Manual acceptance | Pass / Fail / NA |  |

---

## 2. Implemented Files

| File | Change summary |
|---|---|
| `{path}` |  |

---

## 3. Spec

| Item | Yes/No | Notes |
|---|---|---|
| Spec implemented |  |  |
| Plan followed |  |  |
| All tasks completed |  |  |
| Task actual results filled |  |  |

---

## 4. Drift Check

### 4.1 No Drift Evidence

- {If no drift exists, write evidence; otherwise write N}

### 4.2 Execution Doc Drift

Code differs from Spec / Plan / Tasks but does not affect Truth:

- {None or drift list}

Suggested backfill:

- [ ] Update spec
- [ ] Update plan
- [ ] Update tasks

### 4.3 Truth Drift

Code changes, extends, or violates SoT / ADR:

| Drift | Code behavior | Truth rule | Suggested resolution |
|---|---|---|---|
| {item} | {behavior} | {rule} | Fix code / Update Truth / New SP or ADR |

If this section is non-empty, Closure Decision must be `HUMAN_TRUTH_DECISION_REQUIRED`.

---

## 5. Closure Decision

Choose exactly one:

- `CLOSE`: code, execution docs, and Truth are aligned.
- `BACKFILL_EXECUTION_DOCS`: only spec / plan / tasks need backfill; Truth does not change.
- `HUMAN_TRUTH_DECISION_REQUIRED`: Truth Drift exists and requires Gate B.

Decision: `{CLOSE | BACKFILL_EXECUTION_DOCS | HUMAN_TRUTH_DECISION_REQUIRED}`

---

## 6. Gate B Required if Truth Drift Exists

If Decision is `HUMAN_TRUTH_DECISION_REQUIRED`, the human must choose:

1. Fix code so code matches Truth.
2. Accept code and update Truth.
3. Create / update SP or ADR before deciding.

Human decision:

{to be filled}

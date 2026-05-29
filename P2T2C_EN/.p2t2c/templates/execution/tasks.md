# Tasks {NNN}: {Feature Name}

Based on: `spec.md` + `plan.md`
Rule: run the acceptance command before completing a task, then backfill Actual.

---

## Task Granularity Rules

- One Task = one independently acceptable deliverable.
- One Task should be roughly one meaningful commit.
- One Task should usually touch no more than 5 files.
- Split when scope grows.
- Execute one Task at a time.

---

## Phase 1: {Phase Name}

### Task 1.1: {Task Name}

Status: Not Started | In Progress | Done | Blocked
Depends on: None | Task X.Y

Truth references:

- `{docs/sot/...}` — `{RULE-...}`

Files:

- `{path}` — Add / Modify

Operations:

1. {What to do; do not write full code.}
2. {Key data, enum, interface path, or boundary condition.}

Acceptance:

Each acceptance step names the Truth rule identifier it accepts (RULE-GOV-011), matching the EARS tags in `spec.md`.

Acceptance scope: `single`

- [ ] `{command}` — Verifies: `{RULE-...}` | Expected: {expected} | Actual: {fill after run}
- [ ] Behavior: {expected behavior} — Verifies: `{RULE-...}` | Actual: {fill after check}

Failure Actual examples:

- `Actual: Fail (unit_assertion, retries: 1) -> fixed by {change}; re-ran {command}; Pass`
- `Actual: Fail (sandbox_environment, retries: 1) -> re-ran {command}; Pass`

Drift notes:

- {If Execution Doc Drift or Truth Drift appears, record it and stop or leave it for Closure.}

---

## Final Acceptance Gate

- [ ] All tasks Done.
- [ ] All task Actual results filled.
- [ ] Every task declares `Acceptance scope:`.
- [ ] Any retried or stopped failure has a triage label and retry count in task Actual.
- [ ] Project-defined feature-level closure command passed.
- [ ] Closure Report generated.
- [ ] Closure Decision is one of: `CLOSE`, `BACKFILL_EXECUTION_DOCS`, `HUMAN_TRUTH_DECISION_REQUIRED`.

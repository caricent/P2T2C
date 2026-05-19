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

- [ ] `{command}` — Expected: {expected} | Actual: {fill after run}
- [ ] Behavior: {expected behavior} | Actual: {fill after check}

Drift notes:

- {If Execution Doc Drift or Truth Drift appears, record it and stop or leave it for Closure.}

---

## Final Acceptance Gate

- [ ] All tasks Done.
- [ ] All task Actual results filled.
- [ ] Feature-level build/test/check passed.
- [ ] Closure Report generated.
- [ ] Closure Decision is one of: `CLOSE`, `BACKFILL_EXECUTION_DOCS`, `HUMAN_TRUTH_DECISION_REQUIRED`.

- [ ] feature-level build

# P2T2C_AGENTS.md — AI Entry

P2T2C 0.16 supports one person and AI delivering quickly and reliably: agree on the goal, work continuously, check results, and finish with a short record. Only docs/sot/** defines current rules. Read applicable original clauses and dependencies, not every matching document or every entry point on every step.

## Start and Continue

- R0 creates no workflow artifact. Requested reports or plans remain deliverables, not implementation authorization.
- Identify the current work. Preserve existing standard, compact, or legacy identity; historical CPKs do not route new work into legacy.
- The model chooses records: prefer compact v2 with one SP for eligible clear simple R1 when integration supports it; otherwise retain standard v1 with SP + design.md + tasks.md. Do not ask the user to select templates.
- Do not reconfirm clear R1 or explicitly decided R2 semantics. Pending R2 stops; after the decision, update SOT and necessary DEC before affected implementation.
- The model chooses retrieval, decomposition, implementation, diagnosis, and checks. Repair ordinary failures within authorization without per-step approval. Match checks to impact and reuse applicable results; avoid full regression after each step or invented tests for low-impact text edits.
- Record results, actual check scope and sources, unverified parts, and necessary continuation in compact SP or standard tasks. No mandatory six-column table or separate handoff.

## Stop Actions and Completion

- Code violating clear SOT is an R1 repair. New semantics or conflicting rules need the relevant decision. Compare changed bindings before resolving them; do not blindly refresh digests.
- Stop unauthorized dangerous actions, overwriting user edits, and actions requiring missing environments. Existing authorization remains valid for unchanged action, target, and scope.
- Known failures, unresolved Critical findings, unfinished obligations, or missing/stale necessary acceptance block completion. Set Known blockers: present for those gaps.
- Without blockers run `.p2t2c/bin/p2t2c archive --proposal SP-... --json` once; existing standard also retains `archive --spec NNN-name --json`. Use the project wrapper where one exists. Do not precede closure with a sequence of structural, readiness, and repository-wide validation; Archive reuses internal checks without rerunning project tests.

## On Demand References

- Current SPs live in docs/proposals/; standard design and tasks live in docs/specs/.
- Fields and command examples: P2T2C_README.md and .p2t2c/templates/core/.
- Full governance: docs/sot/governance/P2T2C_GOVERNANCE.md.
- Only work with an existing CPK/run uses legacy context/status/evidence/verify/close. Do not convert configuration or evidence.
- Read cold archive, raw legacy output, or migration records only for the corresponding recovery, conflict, or audit.

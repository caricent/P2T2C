# P2T2C_AGENTS.md — AI Entry

P2T2C 0.15 defaults to these core actions:

```text
Explore optional -> Propose -> Apply -> Verify optional -> Archive
```

## New Work

1. R0 read-only exploration creates no artifact.
2. R1/R2 creates `docs/proposals/SP-YYYYMMDD-short-title.md`.
3. Create exactly design.md and tasks.md under `docs/specs/<NNN-short-title>/`.
4. R1 uses existing SOT. Stop on pending R2; after approval, update SOT before Apply.
5. Apply implements SP observable outcomes and runs tests according to project practice. Do not load P2T2C verification profiles, ledgers, receipts, or cold archive.
6. Verify is optional and reports completeness, correctness, and coherence.
7. When completion conditions hold, run:

```bash
.p2t2c/bin/p2t2c archive --spec <NNN-short-title> --json
```

Archive runs no tests, review, CI, or release smoke.

## Stop Conditions

- R2 decision is pending.
- Implementation reveals Truth drift.
- A known test failure, Verify Critical, or incomplete task exists.
- A dangerous action lacks explicit authorization.
- Existing user changes would be overwritten.

## Document Authority

- Current behavior is defined only by `docs/sot/**`.
- SP contains why/what; design contains how; tasks contain execution and completion.
- Decision rationale uses `DEC-*` records inside SOT.
- `docs/reference/archive/**` is non-authoritative cold history and is forbidden by default.

## Legacy Compatibility

When an existing `docs/reference/archive/change_packs/CPK-*.md` or `.p2t2c/runs/**` is present, that work continues through 0.14.x context/status/evidence/verify/close. Do not convert legacy work or change its configuration or evidence merely because 0.15 was installed.

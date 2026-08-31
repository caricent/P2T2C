# P2T2C Core Workflow

P2T2C means Proposal-to-Truth-to-Code. Version 0.15 draws on OpenSpec's action-oriented workflow and reduces the default path to:

```text
Explore optional -> Propose -> Apply -> Verify optional -> Archive
```

P2T2C governs proposals, SOT, human decisions, known blockers, and document safety. Project tests, CI, and code review remain part of the project's engineering system.

```mermaid
flowchart TD
    U([User request]) --> E{Explore needed?}
    E -->|Yes| X[Read-only Explore]
    E -->|No| P[Propose]
    X --> C{Clear change?}
    C -->|No| R0([R0 ends])
    C -->|Yes| P
    P --> SP[Create SP]
    SP --> D[Create design.md]
    D --> T[Create tasks.md]
    T --> R{Change SOT?}
    R -->|No, R1| A[Apply]
    R -->|Yes, R2| H{Decision approved?}
    H -->|No| STOP[/Wait for human decision/]
    H -->|Yes| S[Update SOT and Decision Record]
    STOP --> S
    S --> A
    A --> I[Implement business behavior]
    I --> Q[Use project tests, CI, and review as needed]
    Q --> DR{Truth drift found?}
    DR -->|Yes| REVISE[Revise SP and design; set decision pending]
    REVISE --> STOP
    DR -->|No| V{Verify needed?}
    V -->|Yes| OV[Optional Verify]
    V -->|No| B{Known blocker?}
    OV --> B
    B -->|Yes| FIX[Fix or obtain a decision]
    FIX --> A
    B -->|No| AR[Archive]
    AR --> DONE([Mark tasks completed in place])
```

## Active Documents

```text
docs/proposals/SP-*.md
docs/specs/<NNN-change>/design.md
docs/specs/<NNN-change>/tasks.md
docs/sot/**
```

- R0 creates no artifact.
- R1/R2 creates SP, design, and tasks.
- SP defines why/what; design defines how; tasks record implementation and completion.
- R2 receives a decision and updates SOT before Apply.
- Completed specs stay in place.

Templates live under `.p2t2c/templates/core/`.

## Archive

```bash
.p2t2c/bin/p2t2c archive --spec <NNN-change> --json
```

Archive checks only pending decisions, incomplete tasks, known failures, dangerous-operation authorization, and R2 Truth digest, then atomically marks tasks status completed. It runs no tests, review, CI, or release smoke and creates no CR, event, receipt, or sidecar.

## Optional Verify

Verify checks completeness, correctness, and coherence. Its absence does not block; an unresolved Critical is recorded in tasks Completion and blocks Archive.

## Cold Archive and Migration

Historical ADRs, CPKs, CR/evidence, and legacy specs live under `docs/reference/archive/**` and have no current authority. Existing projects use explicit migration:

```bash
.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map FILE --json
.p2t2c/bin/p2t2c docs-migrate --apply --decision-map FILE --json
.p2t2c/bin/p2t2c docs-migrate --rollback .p2t2c/docs-migrate/ID/report.json --json
```

Normal upgrade never migrates project documents. Active 0.14.x CPK/runs must close through the legacy workflow first.

## Attribution

The action model, design/tasks split, and artifact-dependency idea draw from Fission-AI/OpenSpec; see `docs/reference/OPENSPEC_ATTRIBUTION.md`.

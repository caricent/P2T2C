---
artifact: design
schema_version: 1
proposal: docs/proposals/SP-20260831-core-workflow-document-governance.md
status: ready
---

# Technical Design

## Context references

- SP-20260831-core-workflow-document-governance.
- P2T2C Governance RULE-GOV-001 through 020.
- Fission-AI/OpenSpec action and schema design.

## Technical decisions

- New work uses SP + design.md + tasks.md, while SOT directly carries behavioral contracts.
- New Archive uses an independent Documents module rather than extending the legacy evidence engine.
- Legacy CPK/runs continue through context/evidence/verify/close.
- docs-migrate is an explicit cold path with decision map, lock, backup, and report.
- Completed specs remain in place; cold archive stores only old formats.

## Interfaces and data flow

- AI Propose writes SP/design/tasks.
- Apply invokes only project engineering tools.
- p2t2c archive --spec ID validates the three documents and SOT, then updates tasks.
- p2t2c docs-migrate provides dry-run/apply/rollback.

## Data or migration design

- Move submit_proposals SP leaves into docs/proposals.
- Move root specs, ADR, CPK, and CR/evidence byte-for-byte into reference/archive.
- Rewrite active references from a frozen map; every ADR mapping targets an existing DEC anchor.

## Risks and trade-offs

- Explicit migration prevents upgrade from rewriting project documents but requires one deliberate operation.
- Old projects retain legacy and core tools until migration.
- Optional Verify reduces workflow cost while known failures still hard-block Archive.

## Open questions

- None.

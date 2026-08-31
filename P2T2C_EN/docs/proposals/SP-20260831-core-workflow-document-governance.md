---
artifact: proposal
schema_version: 1
id: SP-20260831-core-workflow-document-governance
status: approved
risk: R2
decision: approved
decision_ref: user_instruction
specs_ref: docs/specs/016-core-workflow-document-governance
truth_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_digest: cac43bb931cb3134aec67c33dc86a04dd857563eee3abdcb4ae695a639a1cd13
---

# SP-20260831-core-workflow-document-governance

## Why

- Version 0.14.1 and the early 0.15 candidate spent too much attention on proof, acceptance, and workflow artifacts, making small tasks unacceptably slow.
- Adopt an OpenSpec-style action workflow while reusing P2T2C SOT to reduce default documents and runtime control surface.

## What changes

- Default actions become Explore, Propose, Apply, optional Verify, and Archive.
- Active documents become proposals, specs, and SOT.
- New changes use only SP, design.md, and tasks.md.
- ADR decisions move into SOT, while old artifacts move into cold archive.
- Normal upgrade does not migrate documents; explicit reversible docs-migrate is provided.
- Archive runs no tests, review, CI, or release smoke.

## Non-goals

- Do not replace project tests, CI, code review, or release systems.
- Do not rewrite historical CPK, CR, ADR, or legacy specs content.
- Do not migrate a project with an active CPK/run.

## Observable outcomes

- A clear R1 moves directly from user instruction into Propose/Apply without another confirmation.
- Every new specs directory contains only design.md and tasks.md.
- Archive updates only tasks status.
- Active 0.14.x work remains closable after upgrade.
- Document migration dry-run writes nothing and apply/rollback is byte-exact.

## Truth impact

- Update P2T2C Governance for core actions, the document matrix, Decision Records, quality boundaries, and migration rules.

## Decision

- The user explicitly approved the complete design, so decision is approved.

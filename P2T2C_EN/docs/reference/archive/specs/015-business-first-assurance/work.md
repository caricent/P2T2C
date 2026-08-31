---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260831-business-first-assurance.md
---

# Work 015: Core Workflow and Document Governance

## Interfaces and data flow

- Propose: user instruction -> SP -> design.md -> tasks.md.
- Apply: SP/SOT -> business implementation and project-native checks; learning updates SP/design.
- Archive: read only proposal/design/tasks/SOT, check known blockers, atomically update tasks status.
- docs-migrate: explicit decision map -> byte-exact cold archive + active-reference rewrite + reversible report.
- Legacy: existing CPK/runs continue with context/status/evidence/verify/close.

## Task DAG and exclusive scope

| ID | Scope | Dependency | Acceptance |
|---|---|---|---|
| W1 | Truth, DEC records, core templates/schemas | Gate A | clear three-document responsibilities and explicit legacy ADR disposition |
| W2 | Documents, Archive, CLI | W1 | correct completion gates and no project-command execution |
| W3 | docs-migrate, install/upgrade, transaction safety | W1/W2 | zero-write dry-run, byte-exact apply/rollback, active-run refusal |
| W4 | manifest/inventory, README, parity/smoke | W1-W3 | bilingual and frozen-upgrade fixtures pass |

## Verification, review, and recovery

1. Focused fixtures cover R0, R1, pending/approved R2, Archive blockers, and no test orchestration.
2. Migration/security/transaction suites cover collision, symlink/hardlink, failure recovery, and rollback.
3. W1-W4, global, and compatibility-specialist independent reviews have zero findings.
4. Current legacy work runs final full + governance and release smoke all before closure, then explicitly migrates the document layout.

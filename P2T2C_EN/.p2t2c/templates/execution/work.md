---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-YYYYMMDD-short-title.md
---

# Work {NNN}: {Feature Name}

Use only for `execution_shape: architectural`. This file organizes execution; it does not repeat CPK or define business rules.

## Interfaces and Data Flow

- Affected interfaces, schemas, or I/O:
- Component data flow:
- Compatibility and migration boundaries:

## Task DAG and Ownership

| Unique batch ID | Prerequisite | Exclusive files/modules | Implementer tier | Acceptance |
|---|---|---|---|---|
| B1 | None | `{path}` | fast / standard / strongest |  |

- Single integration controller:
- CPK implementer and contract digest:
- CPK `ownership_batches`, exactly matching table IDs:
- `legacy_startup_evidence` and old-trio basis:
- Homogeneous microtask batching:
- Implementer/reviewer recursive fan-out is forbidden.

## Integration Order

1.
2.

## Verification and Review

- Mandatory path mapping, mapping digest, and command IDs for every changed path:
- fast / impacted inner loop:
- complete final-tree full set for R2/multi-Agent:
- complete same-final-tree governance set when `governance_change: true`:
- `batch` review:
- `global` review:
- `specialist` review when `specialist_review_required: true`:
- `re_review` linked to original batch/scope:
- Reviewer differs from implementer; Critical/Important/Minor are zero:

## Drift and Recovery

- Execution-shape/risk upgrade conditions:
- File-based brief/diff/evidence paths:
- Recovery point after context compaction:
- Execution Doc Drift backfill:
- Gate B event/decision/ref/Truth Patch ref when resolved:
- Receipt trust: `local_consistency`, non-adversarial local consistency
- Receipt `methodology_enforcement` / `evidence_completeness` / `evidence_warnings` and matched profiles/paths:
- Atomic-close rollback/retained run state:

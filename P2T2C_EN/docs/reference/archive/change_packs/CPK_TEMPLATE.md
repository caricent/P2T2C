---
artifact: change_pack
schema_version: 3
id: CPK-YYYYMMDD-short-title
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: bounded
production_code_change: false
multi_agent: false
work_pack: none
implementer: agent-id
tdd_policy: required
governance_change: false
specialist_review_required: false
truth_patch_ref: none
truth_patch_digest: none
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: none
legacy_startup_evidence: false
---

# CPK-YYYYMMDD-short-title

## Intent and Boundaries

- Goal:
- Non-goals:
- Source:

## Routing

- Risk and rationale:
- Execution shape and rationale:
- Upgrade conditions:
- Related Truth / ADRs:

## Acceptance and Implementation Strategy

- Observable acceptance outcome:
- Minimum implementation strategy:
- Impact surface:
- Verification profile: fast / impacted / full / governance
- Mandatory mapping and command IDs for every changed path:

## Truth Patch

Write `Not required` for R1. For R2, describe the pending or applied Truth / ADR change; do not apply while `gate_a: pending`.

## Execution and Ownership

- Work batch:
- File ownership:
- Isolation and baseline:
- Agent roles and model tiers:
- Architectural `work_pack`: `specs/{NNN-feature}/work.md`
- Implementer identity, which must differ from reviewers:
- Bounded/spike uses `ownership_batches: none`; architectural lists comma-separated unique batch IDs:
- Only architectural work bootstrapped under the legacy workflow uses `legacy_startup_evidence: true` and retains spec/plan/tasks:

## Method Checkpoints

- Falsifiable test and RED/GREEN, or exemption and alternative evidence:
- TDD policy: `required | exempt | not_applicable`; exempt requires a `tdd_exemption` event:
- Repair owner and two-round limit:
- Review level and specialist review:
- Batch review per architectural ownership ID; bounded batch_id=none; re_review links original scope after fixes:
- Parallel boundaries:

## Gate B and Truth Patch Traceability

- R1 requires `truth_patch_ref` / `truth_patch_digest` to be `none`. R2 references one existing `docs/sot/**` file and records its current SHA-256; refresh digest after any Truth edit.
- When Gate B does not trigger, use `gate_b_status: not_triggered`, `gate_b_decision: none`, and `gate_b_ref: none`.
- `gate_b_status` allows only `not_triggered | resolved`. Resolved records a structured `gate_b` event, and nonempty decision/ref reference both the human decision and applied Truth Patch.
- `execution_shape: spike` cannot use `status: applied` or close; upgrade to bounded/architectural first.
- New bounded work rejects legacy spec/plan/tasks; only architectural + `legacy_startup_evidence: true` is a transition exception.

## Blockers

- None

## Closure Evidence

Keep empty while active. Close requires a verification profile and atomically projects one receipt-v2 line, checks, and cleans; raw events enter a `docs/closure/evidence/**` sidecar. Advisory method gaps enter warnings with incomplete completeness; all findings are zero.

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->

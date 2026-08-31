---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260826-adaptive-v2.md
legacy_startup_evidence: true
startup_profile: p2t2c-balanced-v1
---

# Spec 014: Adaptive Autonomy and Machine Evidence

> This is execution evidence created on 2026-08-26 when the R2 change started under v0.13. It does not mean adaptive-v2 still requires spec/plan/tasks, and it cannot override current CPK or SoT.

## Goals and Non-goals

- Goal: Scale workflow artifacts by risk and execution shape and replace handwritten pass claims with final-tree machine evidence.
- Non-goals: Weaken Truth/Gates, add a Superpowers runtime dependency, or rewrite historical artifacts.

## Truth References

| Truth / ADR | Related rule or decision |
|---|---|
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | RULE-GOV-001, 003, 014, 015, 016 |
| `docs/adr/ADR-014-adaptive-autonomy-and-machine-evidence.md` | Adaptive autonomy and machine-evidence decision |

## Acceptance Behavior

- R0 is zero-document by default; bounded R1 has only CPK v3; architectural uses one work; R2 creates CR automatically.
- Bounded rejects the old trio. This 014 retains startup evidence only because architectural + CPK legacy=true. W1/W2/W3 are unique ownership IDs and each needs batch review.
- R2 Truth ref names one SoT file with matching digest; every changed path matches mapping.
- Advisory still hard-rejects Gate/Truth digest/mapping/contract/final tree/atomic-close failures. Method gaps become structured warnings and incomplete completeness, never a complete claim.
- Bilingual release, historical v2 compatibility, install/upgrade, and managed-file inventory remain safe and aligned.

## Behavior and Test Strategy

- Deterministic fixtures cover parser/schema, artifact matrix, gates, local-consistency negative inputs, and install/upgrade, but do not prove real Agent behavior or adversarial tamper resistance.
- Behavior eval alone assesses control/treatment routing, quality, and efficiency; this batch does not claim it ran or passed.

## Boundary

- New business, security, permission, or persistent-data semantics return to Gate A; clear Truth violations are corrected first.

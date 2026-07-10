---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260710-superpowers-method-layer.md
---

# Spec 013: Superpowers Method Layer

## Goals and Non-goals

- Goal: make five native engineering methods available without weakening P2T2C governance.
- Non-goal: require an external plugin or rewrite historical artifacts.

## Truth References

| Truth / ADR | Related rule or decision |
|---|---|
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | RULE-GOV-014, RULE-GOV-015 |
| `docs/adr/ADR-013-superpowers-method-layer.md` | Native method-layer decision |

## Acceptance Behavior

- A new installation receives all five native method skills and a required balanced configuration example.
- A project without method configuration remains advisory-compatible.
- A required-mode method-enabled R2 closure cannot pass governance checks without method evidence and independent review.

## Behavior and Test Strategy

- Test-first behaviors: checker fixtures exercise required versus advisory method enforcement.
- Exemptions and alternative evidence: release parity, checksums, and install/upgrade smoke tests validate managed asset delivery.

## Boundaries

- Return to Intent Admission for a new semantic boundary, Truth conflict, or high-risk concern.

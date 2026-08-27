---
name: p2t2c-admit-route
description: Use minimal deterministic context for intent admission, Truth discovery, risk x execution-shape routing, and Gate A.
---

# Admission and Routing

## Input

1. Run `p2t2c context --phase admit-route --intent-file - --json`; raw intent is not written into the capsule.
2. Read the exact Truth/ADR, relevant code, and tests pointed to by the capsule. On `UNINDEXED_PROJECT_TRUTH`, search `docs/sot/**/*.md` by intent (excluding History) before routing. Capsule hints are neither route nor Truth.

## Output

- Testable goal/non-goal, authority boundary, Truth ref+digest, `R0|R1|R2`, and `spike|bounded|architectural`.
- Create/update CPK v3 and applicable work under the artifact matrix; the first machine event is `route`.
- Record `gate_a: satisfied` for fully decided R2 work; use pending only for genuinely undecided semantics.

## Stop Conditions

Stop only for undecided R2 semantics, Truth conflict, dangerous/irreversible/external side effect, or missing permission. Gate A pending records safe read-only exploration only. Load `design-refinement` on demand for material ambiguity; do not load another phase skill.

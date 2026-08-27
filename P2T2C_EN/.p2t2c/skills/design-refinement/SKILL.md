---
name: p2t2c-design-refinement
description: Clarify outcome-changing ambiguity in the P2T2C Admission + Routing loop without creating competing Truth.
---

# Design Refinement

Use only when ambiguity changes acceptance, risk, execution shape, or a security/permission/data boundary.

1. Read the entry, config, related Truth/ADRs, and implementation evidence; distinguish discoverable facts from real preferences.
2. State goal, non-goals, observable acceptance, and the exact undecided question.
3. Present mutually exclusive feasible options, a recommendation, and effects on Truth, risk, shape, and verification.
4. Record the decision in current instruction, optional SP, or R2 CPK. A current-behavior change requires Gate A and Truth Patch.
5. While Gate A is pending, record only safe read-only `exploration`, with no implementation/Truth write or close. After decision, resume routing and record risk/shape change as `route`.

This method only clarifies intent. Its output cannot be the sole source of a business rule.

---
name: p2t2c-risk-aware-tdd
description: Use falsifiable, tree-bound test-first development for automatable P2T2C R1/R2 behavior.
---

# Risk-aware TDD

1. Define the smallest test from Truth, CPK, and acceptance, and first state which production defect makes it fail.
2. Do not derive expected values from production logic under test; the test must fail under a genuinely wrong implementation.
3. With `tdd_policy: required`, observe RED through the run recorder, make the minimum implementation, and record GREEN; both bind tree SHA and current `contract_digest`.
4. For generators, checkers, prompts, or skills, prefer consumer behavior over a text-existence grep. When applicable, temporarily mutate the critical condition to confirm test failure, then restore it.
5. After focused verification, run the batch verification required by diff/profile.

A compliant exemption uses `tdd_policy: exempt` plus a `tdd_exemption` event with reason and alternative command/result; use `not_applicable` only when no testable behavior exists. Spike still cannot close. Never infer new business behavior from tests; return to admission/routing on conflict.

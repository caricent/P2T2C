---
name: p2t2c-risk-aware-tdd
description: Apply test-first development to P2T2C R1 and R2 work when behavior can be automated.
---

# Risk-aware TDD

For a testable R1 or R2 behavior, define the intended behavior from Truth, CPK, and spec, write the smallest failing test, observe the expected failure, implement the minimum change, then run the focused and batch verification commands.

Use a documented exemption only for generated output, pure configuration, exploration, or behavior that cannot be automated reasonably. Record the reason and an equally specific alternative verification in the execution documents and CR.

Do not infer new business behavior from a test. If a desired test contradicts or extends Truth, return to intent admission and risk routing.

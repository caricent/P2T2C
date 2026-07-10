---
name: p2t2c-independent-review
description: Independently review R1 production-code and R2 P2T2C work before closure.
---

# Independent Review

Review the completed batch with context limited to its changed files, CPK, spec, Truth, ADRs, and verification evidence. Review in two passes:

1. Check compliance with Truth, CPK, spec, risk classification, and Gate A/B state.
2. Check correctness, security, maintainability, tests, and verification quality.

Critical and Important findings block `CLOSE` until repaired and re-verified. Minor findings are repaired or explicitly accepted in the CR remaining risks. The implementer must independently verify reviewer claims before closure.

R1 requires this method when production code changed. R2 always requires it. R0 uses normal self-review unless project configuration raises the requirement.

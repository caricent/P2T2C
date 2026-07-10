---
name: p2t2c-root-cause-debugging
description: Diagnose a P2T2C verification failure before attempting an autonomous repair.
---

# Root-cause Debugging

Before the first repair, capture the complete failure, reproduce it when possible, inspect relevant changes and working patterns, and trace the failing input or state to its source. State one testable root-cause hypothesis and make the smallest repair that tests it.

Run the relevant verification after every repair. An environment failure may receive one unchanged retry. After two repair rounds for the same failure, stop autonomous repair and return for architecture, Truth, scope, or external-environment assessment.

For a completed repair, record the root cause, hypothesis, repair rounds, and verification evidence in the CR. Do not use this method to bypass a Truth conflict or a required human decision.

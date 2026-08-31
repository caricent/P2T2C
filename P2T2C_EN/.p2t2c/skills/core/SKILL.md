---
name: p2t2c-core
description: Run new 0.15 work through Explore, Propose, Apply, optional Verify, and Archive.
---

# P2T2C Core

- Explore is optional and creates no artifacts.
- R1/R2 require docs/proposals/SP-* plus design.md and tasks.md under docs/specs/<change>/.
- Do not ask again for a clear R1 or an R2 already decided by the user.
- Apply focuses on the SP's observable outcomes and runs tests according to project practice; P2T2C does not orchestrate tests or reviewers.
- If implementation reveals Truth drift, set the SP decision to pending and stop solidifying semantics.
- Verify is optional and reports completeness, correctness, and coherence; unresolved Critical findings go in tasks Completion.
- Archive only invokes p2t2c archive --spec <NNN-name>; it does not run tests, review, or release smoke.
- docs/reference/archive is non-authoritative cold history and cannot replace SOT.
- Existing CPK/runs continue through legacy context/evidence/verify/close.

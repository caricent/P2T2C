---
name: p2t2c-root-cause-debugging
description: Diagnose P2T2C failures before autonomous repair and use the original implementer for at most two scoped rounds.
---

# Root-cause Debugging

Before the first repair, preserve the full failure, reproduce it reliably, inspect the diff and a working pattern, trace failing input/state to its source, and state a falsifiable root-cause hypothesis. Test that hypothesis with the smallest change, not bundled guesses.

- Restore CPK `implementer` and its file-based brief/diff/evidence for both repair rounds; do not rebuild implementation context each round.
- Each `repair` records exact `repair_round`, `hypothesis_digest`, `implementer`, `failure_digest`, `fix_base_sha`, `fix_head_sha`, and `fix_diff_digest`. Re-review uses `review_role: re_review` with original batch/scope.
- One unchanged retry is allowed for a clear environment failure without consuming a code-repair round.
- After two failed rounds, stop for architecture, Truth, scope, or external-environment assessment.

Do not hide failure by rewriting Truth, weakening tests, deleting coverage, or swapping implementers.

---
name: p2t2c-independent-review
description: Review R1 production code and R2 work by risk and execution shape, binding findings to base/head SHA.
---

# Independent Review

The reviewer is independent from the implementer and reads only Truth/ADRs, CPK, applicable work, file-based brief, base/head diff, and machine verification. One review returns both Truth/CPK compliance and code-quality/security verdicts to avoid duplicate reading.

- Bounded R1 production code: one `batch` review with `batch_id: none`.
- Architectural R1 and every R2: one `batch` review per unique CPK ownership batch ID, then `global`.
- `specialist_review_required: true`: add a `specialist` reviewer.
- Homogeneous microtask batch: check every brief item and file to prevent omissions.

Reviewer identity differs from CPK implementer. Record `review_role: batch|global|specialist|re_review`, batch ID, base/head, scope/contract digest, findings, and verdict. re_review links the original review batch/scope.

Any nonzero Critical, Important, or Minor finding in a required review blocks CLOSE. CPK implementer repairs; scoped re-review checks only the finding and fix diff, then confirms final-tree evidence remains fresh.

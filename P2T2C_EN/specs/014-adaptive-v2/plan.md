# Plan 014: Adaptive Autonomy and Machine Evidence

Based on: `spec.md`

> v0.13 startup evidence; current execution index is `work.md`.

## Implementation Strategy

Update governance Truth and schema first, implement machine evidence and release infrastructure in parallel, then run full/governance and independent global review on one final tree.

## Impact Surface

| Module | Action | Owner |
|---|---|---|
| Truth, entries, prompts, skills, templates | Apply adaptive-v2 | Governance/docs batch |
| Recorder, close, checker, fixtures | Machine evidence and SHA binding | Evidence-tooling batch |
| Manifest, config, install/upgrade, migration | One managed inventory and release | Infrastructure batch |

## Risks and Mitigation

| Risk | Mitigation |
|---|---|
| Break historical projects | Missing new config stays advisory; historical v2 artifacts are not migrated |
| Stale Truth/contract/path evidence | Hard-check Truth SHA-256, contract/path-mapping digest, matched paths, and final tree |
| Parallel conflict | Exclusive file ownership, one integration controller, no recursive fan-out |
| Bilingual/inventory divergence | Stable-enum checks and shared `.p2t2c/managed-files.txt` consumption |

## Verification Strategy

- Deterministic: schema, artifact matrix, Gate A/B, historical compatibility, and local-consistency negative inputs without adversarial security claims.
- Delivery: install, upgrade, rollback, checksum, and managed-file parity.
- Atomic closure: inject failure after projection/checker/cleanup and verify target rollback plus retained run state.
- Behavior eval: define control/treatment and scoring; promote required only after real results meet gates plus a human decision.

## Isolation, Collaboration, and Review

- Host-managed workspace with disjoint write ownership.
- Ownership-batch review plus final-tree global review; specialist release/evidence-security review.

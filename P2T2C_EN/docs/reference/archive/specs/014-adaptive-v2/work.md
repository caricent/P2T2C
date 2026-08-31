---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260826-adaptive-v2.md
---

# Work 014: Adaptive Autonomy and Machine Evidence

This architectural execution index becomes effective atomically with the v0.14 Truth Patch. Adjacent `spec.md`, `plan.md`, and `tasks.md` are audit evidence created when this R2 change started under v0.13, not requirements of the new artifact matrix.

## Interfaces and Data Flow

- CPK v3 also binds this Truth/collaboration/startup exception through governance SHA-256, W1/W2/W3 ownership, and legacy=true; refresh digest after any Truth edit.
- Recorder writes exploration, TDD, route/isolation/repair/Gate B, and batch/global/specialist/re_review; close atomically projects a local-consistency receipt.
- Project config defines verification profiles/path mapping; all release consumers read `.p2t2c/managed-files.txt`, while manifest stores only its pointer.

## Task DAG and Ownership

| Unique ID | Content | Prerequisite | Exclusive scope | Acceptance |
|---|---|---|---|---|
| W1 | Governance and bilingual docs | None | Truth, ADR, CPK, prompts, skills, templates, eval | Stable enums and paths align |
| W2 | Machine evidence | CPK contract | Recorder, close, checker, negative fixtures | Stale local SHA/digest/contract mismatch is rejected |
| W3 | Release infrastructure | CPK contract | Managed files, config, install/upgrade, migration, smoke | One inventory drives every consumer |

- Single integration controller: root-task Agent.
- Write batches have disjoint paths; homogeneous bilingual edits batch within their ownership.
- Implementers/reviewers do not recursively fan out.
- W1, W2, and W3 each require an independent `batch` review. Final integration is a controller checkpoint, not a fourth ownership batch, and requires `global` + `specialist`.

## Integration Order

1. Lock CPK/work/CR schema, config wire shape, and new managed paths.
2. Merge W1-W3, run schema/structure checks, and repair interface mismatches.
3. Regenerate checksums; run bilingual, install, upgrade, rollback, local-consistency negative fixtures, and final full/governance checks.
4. Perform independent global/specialist review, use `re_review` after fixing original findings, then atomically project evidence and create the R2 CR.

## Verification and Review

- Complete `verification.full` and complete `verification.governance` each succeed on the same final tree.
- W1, W2, and W3 each use independent `batch`; final integration uses `global`, install/upgrade/evidence security uses `specialist`, and repaired findings use `re_review` linked to the original scope/batch.
- Reviewers differ from `root-controller`; every required review has zero Critical, Important, and Minor findings.
- Receipt uses `evidence_trust: local_consistency` without claiming adversarial tamper resistance.
- Every changed path matches mapping; receipt projects mapping/matched paths, `methodology_enforcement`/`evidence_completeness`/`evidence_warnings`, baseline/risk ref.
- Close atomically projects and runs normal checker; failure rolls back target and retains run state.

## Drift and Recovery

- Already architectural/R2; no downgrade. New undecided semantics return to Gate A.
- Recover from CPK, work, Git diff, `.p2t2c/runs/<work-id>/events.jsonl`, and Agent state.
- Backfill Execution Doc Drift here; Gate B only accepts implementation and changes Truth.

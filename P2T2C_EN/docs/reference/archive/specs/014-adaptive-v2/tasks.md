# Tasks 014: Adaptive Autonomy and Machine Evidence

Based on: `spec.md` + `plan.md`

> v0.13 startup evidence; dynamic state and ownership live in `work.md` and the machine ledger.

## Work Batch

- [x] Task 1: Update bilingual governance Truth, ADR, entries, CPK/work/CR templates, prompts, skills, and Superpowers attribution.
- [x] Task 2: Implement Truth digest/ownership/legacy contract, exploration/re_review/full repair wire, path mapping, advisory completeness/warnings, remaining-risk ref, and atomic close.
- [x] Task 3: Make checker, installer, upgrader, and checksum share `.p2t2c/managed-files.txt`; manifest stores only the pointer.
- [x] Task 4: Add deterministic fixtures and adaptive-v2 behavior-eval scenarios.
- [x] Task 5: Batch-review W1/W2/W3, then global/specialist; use re_review for fixes; atomically create CR after same-tree full+governance.

## Batch Acceptance

- Root `make check` and both release-root checks pass.
- Install/upgrade/rollback/checksum smoke passes.
- Deterministic negative fixtures reject invalid routing/spike close, missing evidence, failed verification, stale SHA/digest, identical reviewer, missing role, nonzero findings, and missing full+governance. They do not replace behavior eval.
- Real Agent eval is reported only after it actually runs; this task delivers the scenario set and cannot claim KPI success or required promotion.

## Batch Boundary

- Excludes Superpowers runtime dependency, historical 013 rewrite, five repair rounds, and uniform human approval.

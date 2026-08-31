# ADR-015: Minimal Context and Equivalent Execution Efficiency

Status: Accepted
Date: 2026-08-27
Change Pack: `docs/change_packs/CPK-20260826-context-execution-efficiency.md`
Truth Patch: `docs/sot/governance/P2T2C_GOVERNANCE.md`
Truth Patch SHA-256: `dffca2ddffd0f0dd4c6d8f5ed222866d9acd0462cd231caccfd64085a69cd57c`

## Context and decision

0.14 established the right machine-evidence and adaptive-governance boundary, but the default entry still repeatedly loaded config, manifest, and phase instructions; CRs embedded the whole ledger; and checker, close, and bilingual smoke repeated equivalent parsing or execution.

0.14.1 separates runtime information into Hot/Warm/Cold, provides deterministic bounded context/status/evidence views, references content-addressed evidence sidecars from receipt v2, and keeps failed output in temporary cold logs. The execution engine uses one index, a strictly limited historical cache, coverage-aware batch verify, one close preparation, and suite-based smoke. Every reuse is bound to artifact/config/tool/schema/Git/final-tree digests.

The methodology profile remains `p2t2c-adaptive-v2` because this release does not alter risk, gates, Agent fan-out, model tiers, review roles, or repair limits. The 0.14.1-C Agent-policy experiments are explicitly excluded.

## Consequences and threat boundary

- Normal Agents no longer read raw config/ledger/historical CR; failure detail is fetched on demand through a safe path and bounded tail.
- Historic inline receipt v1 and full project configs remain byte-compatible; upgrade does not rewrite history or project-owned config.
- Defenses cover sidecar/cache substitution, symlink/hardlink/TOCTOU, partial transaction, concurrency, fallback downgrade, stale capsules, and terminal injection.
- Trust remains `local_consistency`; it cannot resist simultaneous tampering with code, tools, checksums, and evidence, and does not replace CI signatures or remote attestation.
- SIGKILL may leave an unreferenced content-addressed orphan; an old target cannot reference wrong sidecar bytes and the next locked close may safely clean the orphan.

## SoT projection

- RULE-GOV-017 and RULE-GOV-018.

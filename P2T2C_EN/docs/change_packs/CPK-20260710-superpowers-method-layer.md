---
artifact: change_pack
schema_version: 2
id: CPK-20260710-superpowers-method-layer
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-balanced-v1
---

# CPK-20260710-superpowers-method-layer

## Intent and Scope

- Goal: add a native, Truth-governed execution method layer to P2T2C.
- Non-goals: bundle Superpowers, replace the five stages, or turn methods into business Truth.
- Source: approved user plan dated 2026-07-10.

## Risk Routing

- Risk level and reason: R2 because governance Truth, ADR policy, templates, checks, and release upgrade behavior change.
- Related Truth / ADR: RULE-GOV-014, RULE-GOV-015, ADR-013.
- Impact: both monolingual release roots and managed install/upgrade assets.

## Truth Patch

Apply RULE-GOV-014 and RULE-GOV-015. P2T2C remains the control layer; method evidence is schema-aware and historical projects remain advisory-compatible.

## Work Batch

- Suggested feature directory: `specs/013-superpowers-method-layer/`
- Batch boundary: skills, prompts, templates, governance checks, migration, attribution, and bilingual parity.
- Verification set: release checks, checksum verification, and install/upgrade smoke tests.

## Method Checkpoints

- Test-first behavior or exemption: configuration/documentation workflow; validate with release and smoke-test fixtures instead of production behavior tests.
- Isolation and baseline: host-managed workspace; clean baseline checked before work.
- Independent review required: Yes

## Blockers

- None

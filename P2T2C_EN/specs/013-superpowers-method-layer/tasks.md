# Tasks 013: Superpowers Method Layer

Based on: `spec.md` + `plan.md`

## Work Batch

- [x] Task 1: Add native bilingual method skills and provenance reference.
- [x] Task 2: Update governance, entry points, prompts, templates, and project configuration.
- [x] Task 3: Add schema-aware enforcement, migration, and managed install/upgrade paths.
- [x] Task 4: Regenerate checksums and run release plus smoke-test verification.

## Batch-level Acceptance

| Command or step | Expected result |
|---|---|
| `make check` | Both release roots and parity pass. |
| `make checksums` | Both checksum manifests regenerate and verify. |
| Install/upgrade smoke tests | New files deliver safely; historical configuration remains advisory. |

## Batch Method Checkpoints

- RED evidence or exemption: configuration/documentation behavior is validated by negative checker fixtures and smoke tests.
- Root-cause record required when repair occurs.
- Independent review required: Yes

## Batch Boundary

- Excludes: an upstream Superpowers plugin dependency and actual parallel-agent execution.
- Return to Intent Admission for a new semantic boundary, Truth conflict, or high-risk concern.

# Plan 013: Superpowers Method Layer

Based on: `spec.md`

## Implementation Strategy

Add native bilingual methods and integrate their checkpoints into existing five-stage assets, while making enforcement conditional on a declared profile and required project configuration.

## Impact

| Module or file | Action | Responsibility |
|---|---|---|
| `.p2t2c/skills/**` | Add five native method skills | P2T2C |
| Prompts, templates, and governance Truth | Modify | P2T2C |
| Checker, installer, upgrader, migration | Modify | P2T2C |

## Risks and Handling

| Risk | Handling |
|---|---|
| Historical artifact breakage | Default missing configuration to advisory and enforce only declared profiles. |
| Bilingual divergence | Run release parity and maintain identical shell scripts. |
| Method layer overrides Truth | Assert the boundary in governance, entry point, and every method. |

## Verification Strategy

| Check | Command or step | Coverage |
|---|---|---|
| Governance | `make check` | Both roots, contracts, parity |
| Integrity | `make checksums` then `shasum -a 256 -c .p2t2c/CHECKSUMS.sha256` | Managed files |
| Delivery | Install and upgrade smoke tests | New and existing projects |

## Isolation, Collaboration, and Review

- Isolation and clean baseline: host-managed workspace and clean git status before edits.
- Parallel ownership boundaries: not used; both release roots changed as one synchronized batch.
- Independent review checkpoint: inspect diff, checker semantics, and smoke-test output before closure.

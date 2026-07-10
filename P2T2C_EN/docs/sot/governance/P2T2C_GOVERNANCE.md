# P2T2C_GOVERNANCE - Authoritative Workflow Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-07-10

Authority: P2T2C risk routing, Truth boundaries, human gates, work batches, verification repair, drift handling, execution methods, install/upgrade safety, and bilingual release rules.

## RULE-GOV-001: Five-stage Risk-routed Workflow

Status: Active

Rule:

P2T2C uses five stages:

```text
Intent Admission -> Risk Routing and Truth -> Work Batch Execution -> Verification and Repair -> Drift and Closure
```

- Input may be a user instruction, Issue, or optional `SP-*`.
- Continue by default when intent is clear and conflict-free.
- R0 creates no CPK or execution docs; R1/R2 create a persistent CPK and compact execution trio.
- One work batch may contain multiple related tasks serving the same goal and accepted as a whole.
- Every completed R0/R1/R2 change creates a `CR-*`.

Validation:

- `make check`
- CPK, spec, and CR contract checks pass.

Stop the line if:

- A new workflow path is required or risk cannot be classified.

## RULE-GOV-002: Truth Boundary

Status: Active

Rule:

Business rules belong only in `docs/sot/**`. ADRs explain why. SP, CPK, spec, plan, tasks, prompts, tests, code comments, and chat cannot be the only source of a business rule.

Source priority:

1. Human decisions explicitly confirmed in the current task
2. Accepted SPs and ADRs
3. Current `docs/sot/**`
4. Current CPK and execution docs
5. Current code and tests
6. `docs/reference/**`

Validation:

- R1 CPK uses `truth_change: false`.
- R2 updates current SoT after applying a Truth Patch.

Stop the line if:

- A lower-priority source conflicts with a higher-priority source.

## RULE-GOV-003: Risk Routing and Human Gates

Status: Active

Rule:

- `R0`: refactoring, tests, docs, CI changes, or restoring behavior explicitly defined by Truth.
- `R1`: implement behavior already covered by current Truth; create a compact CPK and do not change Truth.
- `R2`: change Truth, ADRs, external contracts, persistent data semantics, security, privacy, permissions, or irreversible operations; create a complete CPK.

Gate A controls only undecided R2 semantics. If the current user instruction already decides complete semantics, record `gate_a: satisfied` without duplicate approval. Do not apply a Truth Patch or enter execution while `gate_a: pending`.

Gate B triggers only for Truth Drift. The allowed decisions are correcting implementation, accepting implementation and updating Truth, or creating new intent/ADR and reassessing.

Validation:

- R1/R2 CPK uses front matter defined by `docs/change_packs/CPK_TEMPLATE.md`.
- Governance check rejects execution docs referencing an R2 CPK with `gate_a: pending`.

Stop the line if:

- Undecided R2 semantics lack a Gate A decision.
- Truth Drift lacks a Gate B decision.

## RULE-GOV-004: Truth Rule Block Style

Status: Active

Rule:

- Important current Truth rules use stable `RULE-{AREA}-{NNN}` identifiers.
- A Rule Block states the rule before validation and stop conditions.
- ADRs explain why; SoT defines current behavior.
- Historical and supersession context remains in Governance History, migrations, and Git history, outside current execution rules.

Validation:

- Rule IDs are unique in current SoT.

Stop the line if:

- A new rule reuses a current Active Rule ID.

## RULE-GOV-006: Two Monolingual Release Roots

Status: Active

Rule:

- `P2T2C_EN/` and `P2T2C_CN/` are self-contained release roots.
- Managed human and AI docs remain monolingual within each root.
- Stable paths, risk values, status values, front matter fields, and script behavior remain aligned.
- The repository root is only the language selector and aggregate check surface.

Validation:

- Root `make check` runs both release checks and the release parity check.
- Checksums and smoke tests pass for both roots.

Stop the line if:

- Stable contracts or managed paths diverge between release roots.

## RULE-GOV-007: Installed Work Surface

Status: Active

Rule:

The installed daily work surface is `docs/` and `specs/`. Internal prompts, scripts, templates, migrations, and metadata live under `.p2t2c/`.

Validation:

- Install and upgrade smoke tests.

Stop the line if:

- Install or upgrade overwrites a project-owned file.

## RULE-GOV-008: Root Entry Files

Status: Active

Rule:

- `P2T2C_README.md` is the human entry.
- `P2T2C_AGENTS.md` is the AI entry.
- New installs do not create generic project-root `README.md`, `AGENTS.md`, or `Makefile`.

Validation:

- Install smoke test.

Stop the line if:

- A new install overwrites project root entry files.

## RULE-GOV-009: Current Rule ID Integrity

Status: Active

Rule:

`RULE-{AREA}-{NNN}` identifiers must be unique across current non-History SoT documents. History is read-only reference and does not participate in current Rule ID uniqueness or bidirectional lifecycle validation.

Validation:

- `make check` scans current non-History SoT documents.

Stop the line if:

- Current Active Truth contains a duplicate Rule ID.

## RULE-GOV-014: Truth-governed Execution Methods

Status: Active

Rule:

P2T2C is the control layer for decision, risk, Truth, gates, and closure. Native execution methods may refine intent or prescribe execution discipline, but cannot define business behavior, replace Truth, alter source priority, or bypass Gate A/B.

- The supported methods are design refinement, risk-aware TDD, root-cause debugging, independent review, and workspace isolation.
- A material ambiguity uses design refinement and remains in the current instruction, optional SP, or R2 CPK; it does not require a parallel design artifact.
- Automatable R1/R2 behavior defaults to test-first development. Generated output, pure configuration, exploration, and impractical automation require a recorded exemption and alternative evidence.
- Every verification repair begins with root-cause investigation and one testable hypothesis. A third repair attempt for the same failure returns for architecture, Truth, scope, or external-environment assessment.
- R1 production-code changes and all R2 changes receive independent two-pass review before closure. Critical and Important findings block closure; Minor findings are repaired or accepted as a remaining risk.
- With `isolation: auto`, use host-managed isolation when available; create or request a worktree only for R2, parallel, or explicitly isolated work. Parallel execution is limited to independent R2 ownership boundaries.

Validation:

- Method-enabled CPK, execution docs, and CRs use the documented method checkpoints.
- R2 closure records an independent review verdict and fresh verification evidence.

Stop the line if:

- A method artifact is used as the sole source of a business rule.
- A required review, root-cause investigation, or method exemption record is missing.

## RULE-GOV-015: Method Evidence Compatibility and Enforcement

Status: Active

Rule:

New installs use `methodology.profile: p2t2c-balanced-v1` and `methodology.enforcement: required`. Existing projects remain compatible in advisory mode until their project-owned `.p2t2c/project_config.yaml` opts into required enforcement. Historical CPK, spec, plan, tasks, and CR artifacts are never migrated solely for this method layer. New CPK and CR templates declare `schema_version: 2`; a v2 CR must declare `verification_policy: fresh_pass`, which requires a passing verification command and cannot retain a failed one.

New method-enabled CPKs declare `methodology_profile: p2t2c-balanced-v1`; required-mode R1 CPKs also declare `production_code_change: true|false`. In required mode, their closure records Method Evidence: a `RED ... Fail` record or an exemption with alternative evidence, root-cause record, required independent review result with zero Critical and Important findings, and isolation/baseline state. A method-enabled `CLOSE` requires at least one fresh passing verification command and no failed verification command.

Validation:

- Governance checks enforce method evidence only for declared method-enabled artifacts in a project configured for required enforcement.
- Advisory and historical artifacts remain valid while receiving actionable guidance.

Stop the line if:

- A required-mode R2 closes without independent review or fresh verification evidence.
- A required-mode method-enabled artifact omits required evidence.

## Work Batches and Execution Docs

- R0 executes directly without `specs/{feature}/`.
- R1/R2 use compact `spec.md`, `plan.md`, and `tasks.md`.
- `spec.md` references the related CPK and Truth.
- `tasks.md` records related tasks and batch-level acceptance commands.
- Per-task Actual results, `Acceptance scope`, code Rule anchors, and per-line EARS Rule tags are not required.

## Verification, Autonomous Repair, and Closure

- Diagnose and repair the first verification failure instead of stopping immediately.
- Allow at most two code or test repair rounds for the same failure and one unchanged retry for a clear environment failure.
- Changed test assertions must cite Truth, CPK, or spec evidence.
- AI automatically backfills Execution Doc Drift.
- Truth Drift requires Gate B.
- Every completed change creates a CR; the normal closure decision is `CLOSE`.

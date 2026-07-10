# P2T2C_AGENTS.md - P2T2C AI Entry Point

This is the only P2T2C AI entry point in this release root.

P2T2C means **Proposal-to-Truth-to-Code**. Continue by default; pause only for undecided semantics, Truth conflicts, dangerous operations, external permissions, repeated verification failure, or Truth Drift.

```text
Intent Admission -> Risk Routing and Truth -> Work Batch Execution -> Verification and Repair -> Drift and Closure
```

## 1. Base Reading

At task start, read:

1. `P2T2C_AGENTS.md`
2. `.p2t2c/project_config.yaml`, or its example if missing
3. `docs/sot/manifest.yaml`
4. SoT, ADRs, code, and tests directly related to the current intent

Do not read `docs/reference/**` or governance history by default. Read them only for historical audit, migration, or conflict investigation.

## 2. Five Stage Prompts

| Stage | Prompt | Main output |
|---|---|---|
| Intent Admission | `.p2t2c/prompts/01_intent_admission_prompt.md` | Clear, conflict-free intent summary |
| Risk Routing and Truth | `.p2t2c/prompts/02_risk_routing_and_truth_prompt.md` | R0, or persistent `CPK-*` |
| Work Batch Execution | `.p2t2c/prompts/03_execute_work_batch_prompt.md` | Code; compact trio for R1/R2 |
| Verification and Repair | `.p2t2c/prompts/04_verify_and_repair_prompt.md` | Actual verification evidence |
| Drift and Closure | `.p2t2c/prompts/05_drift_and_closure_prompt.md` | `CR-*` or Gate B |

## 3. Execution Method Layer

P2T2C is the control layer for risk, Truth, gates, and closure. The optional method layer explains how to execute a permitted batch; it never defines business behavior or overrides Truth.

Read the applicable method in `.p2t2c/skills/` after risk routing:

- `design-refinement` for a material intent ambiguity.
- `risk-aware-tdd` for automatable R1/R2 behavior.
- `root-cause-debugging` before repairing a verification failure.
- `independent-review` before closing R1 production-code or any R2 change.
- `workspace-isolation` before R2, parallel, or explicitly isolated work.

Use the `methodology` configuration when present. Missing configuration means advisory compatibility mode for historical projects; do not fail old CPK, spec, or CR artifacts merely because they predate this method layer.

## 4. Risk Routing

- `R0`: refactoring, tests, docs, CI changes, or restoring behavior defined by Truth. No CPK or execution docs.
- `R1`: implement behavior already covered by current Truth. Create compact `docs/change_packs/CPK-*.md`; do not change Truth.
- `R2`: change Truth, ADRs, external contracts, persistent data semantics, security, privacy, permissions, or irreversible operations. Create a complete CPK.

R1/R2 use compact `spec.md`, `plan.md`, and `tasks.md` in `specs/{NNN-feature}/`. One work batch may contain multiple related tasks.

Every completed R0/R1/R2 change must create `docs/closure/CR-*.md`.

## 5. Human Gates

Gate A controls only undecided R2 semantics:

- If the current user instruction already decides complete semantics, record `gate_a: satisfied`; do not request duplicate approval.
- If semantics remain undecided, record `gate_a: pending`, present explicit options, and pause.
- Do not apply a Truth Patch or enter execution while `gate_a: pending`.

Gate B triggers only for Truth Drift:

1. Correct implementation to match Truth.
2. Accept implementation and update Truth.
3. Create or update intent, SP, or ADR, then reassess.

## 6. Truth Boundary and Source Priority

Business rules belong only in `docs/sot/**`. ADRs explain why. CPK, spec, plan, tasks, tests, code comments, and chat cannot be the only source of a business rule.

Source priority:

1. Human decisions explicitly confirmed in the current task
2. Accepted SPs and ADRs
3. Current `docs/sot/**`
4. Current CPK and execution docs
5. Current code and tests
6. `docs/reference/**`

Pause when a lower-priority source conflicts with a higher-priority source.

## 7. Verification and Pause Boundary

Run applicable Build, Test, Lint, Typecheck, and Governance checks. Before repairing a failure, reproduce and investigate its root cause, compare working patterns, and state one testable hypothesis. Allow at most two repair rounds for the same failure and one unchanged retry for a clear environment failure. Do not claim completion without fresh verification evidence.

Pause only when:

- A material ambiguity or Truth/ADR conflict exists.
- An undecided business, architecture, security, permission, or data semantic is required.
- A dangerous operation or external permission is required.
- The same verification failure exceeds the autonomous repair limit.
- Code changes, extends, or violates Truth.

## 8. Install and Upgrade Safety

Install and upgrade update only the P2T2C workflow shell. They must not rewrite project-owned Truth, ADRs, SPs, CPK instances, specs, code, tests, database files, or historical CRs.

Always run dry-run before apply:

```bash
make p2t2c-install-dry-run TARGET=/path/to/project
cd /path/to/project
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_EN
```

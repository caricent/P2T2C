# P2T2C Risk-Routed Workflow

P2T2C means **Proposal-to-Truth-to-Code**. It lets AI continue by default while concentrating human decisions on undecided semantics and Truth Drift.

```text
Intent Admission
  -> Risk Routing and Truth
  -> Work Batch Execution
  -> Verification and Repair
  -> Drift and Closure
```

The AI entry point is `P2T2C_AGENTS.md`.

## Execution Method Layer

P2T2C governs decisions, risk, Truth, and audit evidence. Its native method layer provides design refinement, risk-aware TDD, root-cause debugging, independent review, and workspace isolation. These methods do not replace Truth or add an external plugin dependency.

New installs enable the balanced profile by default. Existing projects remain compatible in advisory mode until they add the `methodology` section to `.p2t2c/project_config.yaml`.

## Risk Levels

| Level | Applies to | Persistent artifacts |
|---|---|---|
| R0 | Refactoring, tests, docs, CI, restoring existing behavior | `CR-*` |
| R1 | Implementing behavior already covered by Truth | `CPK-*`, compact trio, `CR-*` |
| R2 | Changing Truth, ADRs, external contracts, data semantics, security, permissions, or irreversible operations | Complete `CPK-*`, Truth Patch, compact trio, `CR-*` |

`SP-*` is an optional intent input, not a requirement for every task. R1/R2 CPKs live in `docs/change_packs/`; execution docs live in `specs/{NNN-feature}/`; every completed change creates a CR in `docs/closure/`.

## Human Gates

- Gate A: only for undecided R2 semantics. Do not request duplicate approval when the current instruction already decides them.
- Gate B: only when implementation changes, extends, or violates Truth.

The first verification failure does not immediately stop work. AI diagnoses and repairs within the agreed boundary, pausing only for new decisions, dangerous operations, external permissions, or repeated failure.

## First Install

```bash
cd /path/to/P2T2C_EN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

Then edit the project-owned configuration created by the installer:

```bash
bash .p2t2c/bin/check_p2t2c.sh
```

## Upgrade

From the target project root, invoke the new release script:

```bash
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_EN
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_EN
```

Upgrade changes only unmodified managed workflow files and preserves project-owned Truth, ADRs, SPs, CPKs, specs, code, tests, and historical CRs.

## Directories

| Path | Responsibility |
|---|---|
| `P2T2C_AGENTS.md` | AI entry point |
| `docs/sot/**` | Current business Truth |
| `docs/adr/**` | Decision reasons and consequences |
| `docs/submit_proposals/**` | Optional SP input |
| `docs/change_packs/**` | R1/R2 CPKs |
| `specs/**` | R1/R2 compact execution trio |
| `docs/closure/**` | CRs for every completed change |
| `.p2t2c/**` | Prompts, internal templates, scripts, and upgrade metadata |

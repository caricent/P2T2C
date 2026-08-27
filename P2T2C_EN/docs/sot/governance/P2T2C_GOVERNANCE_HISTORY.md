# P2T2C_GOVERNANCE_HISTORY — Governance Rule Lifecycle History

Status: Reference
Owner: Project maintainers
Last updated: 2026-08-26

This file holds the lifecycle metadata for the rules in `P2T2C_GOVERNANCE.md` (`Source`, `Supersedes`, `Superseded by`, `Migration required`, rationale, downstream projections), plus any `Superseded`/`Deprecated` rule in full.

Not read by default (see `forbidden_default_reads` in `docs/sot/manifest.yaml`). Consult only for historical audit, comparison, migration, or conflict triage.

Starting with 0.12.0, this file is read-only historical reference. Current governance no longer requires an Active/History bidirectional lifecycle graph or validates bidirectional supersession in `make check`. `RULE-GOV-010`, `RULE-GOV-011`, `RULE-GOV-012`, and `RULE-GOV-013` have left the current workflow; their replacement is recorded in `0.11.0-to-0.12.0.md` and Git history.

---

## Lifecycle metadata for Active rules

### RULE-GOV-001

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered workflow section
Superseded by: None
Migration required: Yes, template metadata moves to `0.4.0`

Rationale: One exception-gated path keeps the AI proceeding by default, pausing only at gates or conflicts.

Downstream projections:

- `P2T2C_AGENTS.md`, `.p2t2c/prompts/**`

### RULE-GOV-002

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered document-role table
Superseded by: None
Migration required: Yes, templates become bilingual in-place

Rationale: Concentrating business rules in SoT prevents specs, code, and chat from becoming implicit Truth sources.

Downstream projections:

- `.p2t2c/templates/truth/**`, `.p2t2c/templates/execution/**`

### RULE-GOV-003

Status: Active
Source: Template maintainers; maintainer updates on 2026-05-24
Supersedes: previous unnumbered admission/gate section
Superseded by: None
Migration required: Yes, template version `0.10.1`

Rationale: An Admission Summary plus human gates keeps the AI from deciding conflicts or silently changing Truth. Gate A now uses explicit option choices, and SP drafting is allowed before Gate A because proposal files are inputs rather than Truth changes. CPK generation remains fast when no SoT/ADR change is required; Gate A is reserved for SoT/ADR changes.

Downstream projections:

- `.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md`
- `.p2t2c/prompts/02_generate_change_pack_prompt.md`
- `.p2t2c/prompts/03_apply_change_pack_prompt.md`
- `docs/submit_proposals/SP_TEMPLATE.md`
- `docs/submit_proposals/README.md`
- `.p2t2c/prompts/04_generate_execution_pack_prompt.md`

### RULE-GOV-004

Status: Active
Source: Template maintainers
Supersedes: previous unnumbered Truth document style section
Superseded by: None
Migration required: Yes, Truth templates become bilingual in-place

Rationale: A uniform Rule Block style keeps Truth easy for humans to review and for AI to cite.

Downstream projections:

- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-006

Status: Active
Source: Maintainer decision on 2026-05-19
Supersedes: `RULE-GOV-005`
Superseded by: None
Migration required: Yes, template version `0.5.0`

Rationale: Single-file bilingual documents increase repeated context for AI readers. Dual monolingual release roots preserve language support while reducing per-task reading overhead.

Downstream projections:

- Root selector: `README.md`, `AGENTS.md`, `Makefile`
- English release root: `P2T2C_EN/**`
- Chinese release root: `P2T2C_CN/**`

### RULE-GOV-007

Status: Active
Source: Maintainer decision on 2026-05-20
Supersedes: previous exposed internal asset layout
Superseded by: None
Migration required: Yes, template version `0.6.0`

Rationale: Converge the project-root surface to `docs/` and `specs/`, with internal assets under `.p2t2c/`.

Downstream projections:

- `.p2t2c/ownership.yaml`
- `.p2t2c/manifest.yaml`
- `.p2t2c/bin/**`
- `.p2t2c/migrations/0.5.0-to-0.6.0.md`
- Human and AI entry documents

### RULE-GOV-008

Status: Active
Source: Maintainer decision on 2026-05-20
Supersedes: root-level `README.md` and `AGENTS.md` as P2T2C installed entries
Superseded by: None
Migration required: Yes, template version `0.7.0`

Rationale: Use `P2T2C_README.md` and `P2T2C_AGENTS.md` as install entries to avoid clashing with project-owned root files.

Downstream projections:

- `P2T2C_README.md`
- `P2T2C_AGENTS.md`
- `.p2t2c/CHECKSUMS.sha256`
- `.p2t2c/VERSION`
- `.p2t2c/P2T2C_LICENSE.md`
- `.p2t2c/templates/project_config.example.yaml`
- `.p2t2c/migrations/0.6.0-to-0.7.0.md`

### RULE-GOV-009

Status: Active
Source: Maintainer decision on 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.8.0`

Rationale: Rule identifiers are the stable join key between Truth, specs, tasks, and code. Duplicate identifiers, dangling references, or a superseded rule still marked `Active` silently break that join.

Downstream projections:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-010

Status: Active
Source: Maintainer decision on 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.8.0`

Rationale: Without a back-reference, "which rule does this code implement?" has no machine-checkable answer, and Closure-stage Truth Drift detection has no structural basis.

Downstream projections:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`

### RULE-GOV-011

Status: Active
Source: Maintainer decision on 2026-05-21
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.8.0`

Rationale: EARS statements and a rule's `Validation` field describe the same constraint in two places. Binding them by identifier makes one requirement traceable from Truth through spec and task to its acceptance step.

Downstream projections:

- `.p2t2c/templates/execution/spec.md`
- `.p2t2c/templates/execution/tasks.md`
- `.p2t2c/prompts/04_generate_execution_pack_prompt.md`

### RULE-GOV-012

Status: Active
Source: Maintainer decision on 2026-05-22
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.9.0`

Rationale: Workflow rules only accrue, so reading every active rule by default makes the reading baseline grow linearly with total rule count. Loading by `Phases` and moving lifecycle history out of the default reading path decouples reading cost from total rule count.

Downstream projections:

- `.p2t2c/bin/check_p2t2c.sh`
- `.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md`
- `docs/sot/manifest.yaml`
- `P2T2C_AGENTS.md`
- `.p2t2c/prompts/02_generate_change_pack_prompt.md` through `06_acceptance_and_closure_prompt.md`

### RULE-GOV-013

Status: Active
Source: Maintainer decision on 2026-05-29
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.11.0`

Rationale: Task-chain acceptance merging and failure triage change when acceptance commands run and how failures are handled. Making `Acceptance scope:`, triage labels, and retry counts a self-reporting contract keeps Closure auditable without putting project-stack keywords into governance.

Downstream projections:

- `.p2t2c/prompts/05_execute_single_task_prompt.md`
- `.p2t2c/templates/execution/tasks.md`
- `.p2t2c/bin/check_p2t2c.sh`

### RULE-GOV-014

Status: Active
Source: Maintainer decision on 2026-07-10; adaptive-v2 update on 2026-08-26
Supersedes: Previous fixed method checkpoints
Superseded by: None
Migration required: Yes, template version `0.14.0`

Rationale: The method layer evolves from fixed document/review ceremony to execution-shape-proportional Agent autonomy while retaining Truth, gates, two repair rounds, and independent review.

Downstream projections:

- `.p2t2c/skills/**`
- `.p2t2c/prompts/**`
- `P2T2C_AGENTS.md`

### RULE-GOV-015

Status: Active
Source: Maintainer decision on 2026-07-10; machine-evidence update on 2026-08-26
Supersedes: Schema v2 handwritten method-evidence enforcement
Superseded by: None
Migration required: Yes, template version `0.14.0`

Rationale: Text claims cannot prove execution against final code and the current CPK contract. v3 uses contract digest and final tree for non-adversarial local consistency, structuring TDD, routing, repair, Gate B, and role-specific review.

Downstream projections:

- `docs/change_packs/CPK_TEMPLATE.md`
- `.p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md`
- `.p2t2c/bin/check_p2t2c.sh`

### RULE-GOV-016

Status: Active
Source: Maintainer decision on 2026-08-26
Supersedes: Fixed R1/R2 execution trio and mandatory CR for every risk
Superseded by: None
Migration required: Yes, template version `0.14.0`

Rationale: Risk determines Truth authority while execution shape determines execution/document intensity, reducing duplication for bounded work without weakening R2 control.

Downstream projections:

- `docs/change_packs/**`
- `.p2t2c/templates/execution/**`
- `.p2t2c/manifest.yaml`
- `.p2t2c/managed-files.txt`

### RULE-GOV-017

Status: Active
Source: Maintainer decision on 2026-08-27
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.14.1`

Rationale: Large context windows do not remove attention dilution or repeated reads. Keeping exact Truth and current state Hot/Warm while moving raw events and failure output into verifiable Cold sidecars reduces default context without removing evidence.

Downstream projections:

- `P2T2C_AGENTS.md`
- `.p2t2c/skills/admit-route/**`, `.p2t2c/skills/execute/**`, and `.p2t2c/skills/verify-close/**`
- `.p2t2c/bin/p2t2c`, `.p2t2c/bin/p2t2c_run.sh`, and `.p2t2c/bin/p2t2c_close.sh`
- `.p2t2c/schemas/closure-receipt-v2.schema.json` and context-view schemas
- `docs/sot/manifest.yaml`, `.p2t2c/defaults.yaml`, and `.p2t2c/templates/project_config.example.yaml`

### RULE-GOV-018

Status: Active
Source: Maintainer decision on 2026-08-27
Supersedes: None
Superseded by: None
Migration required: Yes, template version `0.14.1`

Rationale: v0.14 has correct final evidence and safety boundaries, but checker, verification, close, and release smoke repeat parsing or execution. Only equivalence deduplication under strong digest/tree/config bindings is an efficiency improvement; it cannot weaken gates, reviews, repairs, or complete smoke.

Downstream projections:

- `.p2t2c/bin/check_p2t2c.sh` and the single-process checker core
- `.p2t2c/bin/p2t2c`, `.p2t2c/bin/p2t2c_evidence.pl`, and `.p2t2c/bin/p2t2c_close.sh`
- `.p2t2c/project_config.yaml` and `.p2t2c/templates/project_config.example.yaml`
- `scripts/release_smoke_test.sh` and its split fixtures

---

## Superseded rules (full text)

### RULE-GOV-005: English-first Single-file Bilingual Templates

Status: Superseded
Applies to: P2T2C-managed docs, prompts, templates, README files, and migration notes
Source: Template maintainers
Supersedes: `workflow: P2T2C Exception-Gated Workflow CN`, `language: zh-CN`
Superseded by: `RULE-GOV-006`
Migration required: Yes, template version `0.4.0`

Rule:

P2T2C-managed human and AI workflow documents used English-first single-file bilingual presentation.

This rule has been superseded by `RULE-GOV-006` and is retained only as a historical lifecycle record.

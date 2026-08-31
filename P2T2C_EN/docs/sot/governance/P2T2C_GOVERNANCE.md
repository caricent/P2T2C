# P2T2C_GOVERNANCE — Authoritative Workflow Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-08-31

Authority: P2T2C Truth boundaries, R0/R1/R2, human decisions, core actions, active documents, legacy compatibility, installation, upgrades, and bilingual releases.

## RULE-GOV-001: Action-oriented Core Workflow

Status: Active

Rule:

The default actions for new 0.15 work are:

```text
Explore optional -> Propose -> Apply -> Verify optional -> Archive
```

- Explore is read-only and creates no artifact.
- Propose creates the SP, design.md, and tasks.md together.
- Apply implements observable outcomes and uses project tests, CI, and code review according to project practice.
- Verify optionally checks completeness, correctness, and coherence.
- Archive checks only known blockers and marks tasks.md completed in place.
- Actions may revisit earlier documents and are not irreversible phase gates.

Validation:

- New R1/R2 binds SP, design, and tasks.
- R0 creates no workflow artifact.

Stop conditions:

- Apply starts before a clear change exists.
- The default path requires assurance, proof, receipt, or a separate verify-close phase.

## RULE-GOV-002: Truth and Source Boundary

Status: Active

Rule:

Current behavioral authority may exist only in `docs/sot/**`. Source priority is:

1. A human decision explicitly confirmed in the current task.
2. Current `docs/sot/**`.
3. Approved `docs/proposals/SP-*.md`.
4. Current design.md and tasks.md.
5. Current code, tests, and CI.
6. `docs/reference/archive/**`.

SP defines why/what; design defines how; tasks record execution and completion. None can override SOT. Cold archive is never authoritative.

Validation:

- R1 references existing SOT.
- R2 updates and approves SOT before Apply.

Stop conditions:

- A lower-priority source conflicts with a higher-priority source.
- Cold archive is treated as a current rule.

## RULE-GOV-003: Risk and One Human Decision

Status: Active

Rule:

- R0: read-only exploration with no persistent change document.
- R1: implement existing SOT with decision not_required.
- R2: modify SOT, external contracts, persistent-data semantics, or irreversible rules with decision pending or approved.

Gate A/B collapse into `decision: not_required|pending|approved`:

- An explicit, complete user R2 decision may be approved without asking again.
- Pending work cannot Apply, update SOT, or complete.
- Truth drift discovered during implementation returns the SP to pending.
- Dangerous or externally side-effecting actions always require explicit authorization before the action.

Validation:

- Approved R2 binds the current SOT path and SHA-256.
- Dangerous-operation authorization is recorded in tasks Completion.

Stop conditions:

- A pending R2 is implemented or completed.
- A dangerous action lacks authorization.

## RULE-GOV-004: Rule and Decision Record Style

Status: Active

Rule:

- Current rules use unique `RULE-{AREA}-{NNN}` IDs.
- Decision rationale uses unique `DEC-*` records inside the owning SOT.
- Current SOT defines effective behavior; history keeps background, alternatives, consequences, and supersedes.
- New active `docs/reference/archive/adr/**` files are forbidden.

Validation:

- Current Rule and Decision IDs are unique.
- Referenced Decision anchors exist.

Stop conditions:

- A new decision exists only in a standalone ADR or chat.
- A current ID is duplicated.

## RULE-GOV-006: Two Monolingual Release Roots

Status: Active

Rule:

- `P2T2C_EN/` and `P2T2C_CN/` are self-contained monolingual release roots.
- Stable paths, front matter, states, scripts, and migration behavior match.
- Cold archived originals may retain historical language and are excluded from current-language checks.

Validation:

- Root `make check`, parity, and release smoke.

Stop condition:

- Stable bilingual contracts diverge.

## RULE-GOV-007: Installed Active Work Surface

Status: Active

Rule:

Active documents exist only under:

- `docs/proposals/`
- `docs/specs/`
- `docs/sot/`

`docs/reference/archive/` is cold history; `.p2t2c/` contains tools, templates, migration, and legacy compatibility. New work does not use root `docs/reference/archive/specs/`, `docs/reference/archive/change_packs/`, `docs/reference/archive/closure/`, or `docs/reference/archive/adr/`.

Validation:

- Fresh-install layout smoke.

Stop condition:

- Installation overwrites project-owned SP, design, tasks, or SOT.

## RULE-GOV-008: Root Entry Files

Status: Active

Rule:

- `P2T2C_README.md` is the human entry.
- `P2T2C_AGENTS.md` is the AI entry.
- New installs do not create generic project-root README, AGENTS, or Makefile files.

Validation:

- Install smoke.

Stop condition:

- Installation overwrites project-root entry files.

## RULE-GOV-009: Current Truth Integrity

Status: Active

Rule:

- Rule and Decision IDs in non-history SOT are unique.
- `history.md` and `*_HISTORY.md` do not participate in current Rule uniqueness.
- The SOT manifest binds current Truth digests and IDs.

Validation:

- Checker scans current SOT.

Stop condition:

- Current Truth is duplicated, missing, or digest-stale.

## RULE-GOV-014: Core Actions and Agent Autonomy

Status: Active

Rule:

- Do not reconfirm a clear R1 or an R2 explicitly approved by the user.
- Propose creates the smallest three documents needed for implementation.
- Apply works from SP observable outcomes and updates SP/design when learning changes the path.
- Project-native tests, CI, and PR review belong to the project engineering system and are not orchestrated by P2T2C.
- Parallel writes require disjoint ownership and one integration controller.
- Existing user changes must be preserved.

Validation:

- AI does not read legacy ledger, receipt, or cold archive by default.
- Ordinary work does not run P2T2C release smoke.

Stop conditions:

- Agent decides unresolved R2 semantics.
- Workflow mechanics displace business implementation.

## RULE-GOV-015: 0.14.x Legacy Compatibility

Status: Active

Rule:

Open 0.14.x work continues with CPK v3, event v1, receipt v1/v2, context/status/evidence/verify/close, fixed reviews, and atomic close. Its defaults, verification profiles, contract digests, and evidence semantics do not change in 0.15.

Legacy tools load only when an existing CPK/run or explicit legacy command is present. New 0.15 work never creates legacy artifacts.

Validation:

- Frozen 0.13, 0.14, and 0.14.1 fixtures can continue closure after upgrade.
- Config, Truth, CPK, run, event, receipt, and sidecar bytes remain unchanged in unmigrated projects.

Stop conditions:

- Normal upgrade rewrites active legacy work.
- Core Archive invokes legacy verify/close.

## RULE-GOV-016: Active Artifact Matrix

Status: Active

Rule:

| Scenario | Active durable artifacts |
|---|---|
| R0 | none |
| R1 | SP + design.md + tasks.md |
| R2 pending | SP + design.md + tasks.md; Apply forbidden |
| R2 approved | SP + design.md + tasks.md + updated SOT |

- SP is named `docs/proposals/SP-YYYYMMDD-short-title.md`.
- Specs use `docs/specs/<NNN-short-title>/` containing only design.md and tasks.md.
- Completed specs remain in place.
- CPK, plan, spec, work, CR/CP, and ADR are not new-work artifacts.

Validation:

- Proposal/design/tasks references agree.
- Every specs directory contains exactly two files.

Stop conditions:

- New work lacks an SP.
- Design or tasks redefines SOT behavior.

## RULE-GOV-017: Minimal Context

Status: Active

Rule:

AI reads only the user instruction, matching SP, applicable SOT, design, tasks, and business code by default. Verify is optional. Legacy evidence, full failure output, migration journals, and cold archive load only for the matching exception or explicit audit.

Validation:

- P2T2C_AGENTS exposes only core actions and stop conditions.

Stop condition:

- Default context loads cold archive or legacy evidence.

## RULE-GOV-018: Release Tests and Project Quality Boundary

Status: Active

Rule:

Archive runs no tests, review, CI, or release smoke. Apply runs checks only according to project practice. P2T2C installation, upgrade, migration, security, transaction, bilingual, and compatibility smoke run only from explicit P2T2C release CI.

Missing Verify does not block; a known failed test or Verify Critical must be recorded in tasks Completion and blocks Archive.

Validation:

- Archive sentinel fixture proves no project command executed.
- Release smoke runs only from explicit release targets.

Stop conditions:

- Ordinary work triggers P2T2C full tests.
- A known failure is marked complete.

## RULE-GOV-019: Completion and Archive

Status: Active

Rule:

Archive requires:

- SP status approved and decision not pending.
- Design status ready.
- No incomplete task checkbox; deferred tasks carry a decision reference.
- Tests is not failed.
- Verify is not critical.
- Known blockers is none.
- Dangerous operations is not pending; approved includes authorization ref.
- R2 SOT digest is current.

Archive only atomically changes tasks status from in_progress to completed. It creates no receipt, sidecar, or CR.

Validation:

- Archive positive/negative and atomic rollback fixtures.

Stop conditions:

- Archive executes external project commands.
- Partial writes or concurrent user edits are overwritten.

## RULE-GOV-020: Explicit Document Migration

Status: Active

Rule:

Normal upgrade never moves project-owned documents. Layout migration is available only through:

```text
p2t2c docs-migrate --dry-run
p2t2c docs-migrate --apply
p2t2c docs-migrate --rollback <report>
```

Migration moves SP, ADR, CPK, CR/evidence, and legacy specs leaf by leaf; archived originals remain byte-exact. ADR requires an explicit old-ADR to SOT DEC-anchor mapping written by a human first; the migrator never interprets decisions.

Active legacy runs, unclosed CPKs, path collisions, unknown references, symlink/hardlink inputs, or invalid DEC mappings block. The transaction uses a project lock, journal, backups, and after-image verification; rollback refuses with zero writes if concurrent edits exist.

Validation:

- Dry-run performs zero writes.
- Apply/rollback is byte-exact.
- Failure injection and concurrency fixtures pass.
- Cold archive is excluded from current checker semantics.

Stop conditions:

- Upgrade automatically migrates documents.
- Archived originals are rewritten.
- Template rollback runs before document-layout rollback.

## DEC-GOV-013: Method skills have no Truth authority

Status: Active foundation
Date: 2026-07-10

Decision:

P2T2C Truth remains authoritative for method governance. Project method skills may assist execution but cannot override SOT. Full context and consequences remain in `P2T2C_GOVERNANCE_HISTORY.md#DEC-013`.

## DEC-GOV-014: 0.14 layered autonomy and machine evidence

Status: Superseded by DEC-GOV-017 for new work
Date: 2026-08-26

Decision:

CPK v3, event v1, receipts, and fixed review remain only for active 0.14.x legacy work. Full context and consequences remain in `P2T2C_GOVERNANCE_HISTORY.md#DEC-014`.

## DEC-GOV-015: 0.14.1 minimal-context optimization

Status: Superseded by DEC-GOV-017 for new work
Date: 2026-08-27

Decision:

Equivalent deduplication in context/evidence/verify/close remains only for active 0.14.x legacy work; 0.15 new work removes the default evidence control plane. Full context and consequences remain in `P2T2C_GOVERNANCE_HISTORY.md#DEC-015`.

## DEC-GOV-016: Withdraw the assurance-control-plane candidate

Status: Superseded before release by DEC-GOV-017
Date: 2026-08-31

Decision:

The assurance/proof/event-v2/receipt-v3 candidate is not part of 0.15 because it still placed proof process ahead of business implementation. Full context and consequences remain in `P2T2C_GOVERNANCE_HISTORY.md#DEC-016`.

## DEC-GOV-017: Adopt Core Actions and Three-domain Document Governance

Status: Active
Date: 2026-08-31
Supersedes: assurance-based 0.15 preview

Decision:

New P2T2C work uses Explore, Propose, Apply, optional Verify, and Archive. Active documents are proposals, specs, and SOT. Code quality returns to the project engineering system; P2T2C governs Truth, human decisions, known blockers, and document safety.

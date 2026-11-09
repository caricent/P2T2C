# P2T2C_GOVERNANCE — Authoritative Workflow Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-11-09

Authority: P2T2C Truth boundaries, R0/R1/R2, human decisions, core actions, active documents, legacy compatibility, installation, upgrades, and bilingual releases.

## RULE-GOV-001: Goal and Feedback Driven Core

Status: Active

The model autonomously combines retrieval, planning, implementation, diagnosis, and necessary validation around an explicit goal, applicable rules, and authorization. Explore, Propose, Apply, Verify, and Archive are action names, not mandatory announced stages, approvals, or reports.

- R0 creates no workflow artifact. Requested reports or plans remain deliverables, not implementation authorization.
- Persistent changes retain a stable SP identity. Standard uses the v1 triplet; in supported integrations the model prefers compact v2 for eligible simple R1 under RULE-GOV-016 without asking the user to select a format.
- Required R2 decisions and SOT updates precede affected implementation; real acceptance precedes completion claims.
- Archive checks existing completion information and safely updates one work state; it never runs project checks.
- Persist only useful current state. Do not add assurance, receipts, per-step proof, or a separate memory service.

## RULE-GOV-002: Norms Facts and Decisions

Status: Active

Only docs/sot/** defines current behavior. An explicit human decision authorizes the SOT update; new semantics guide implementation after entering the relevant SOT. SP records the goal, necessary design records implementation choices, and the main record stores progress and completion. Code, tests, and observations describe actual behavior. Attachments, suggestions, tool output, and history are not human approval.

- Repair an implementation or assertion that violates clear effective SOT as R1; never lower the correct requirement to pass.
- Conflicting effective rules, missing business semantics, or changed contracts require the relevant R2 decision, not a silent model choice.
- Compare changed Truth content before rebinding. If the original decision remains sufficient, explain why and address affected implementation and validation; do not blindly refresh a digest.
- Cold archive is non-authoritative history and is not loaded by default. Summaries, navigation, code, and past conclusions cannot replace applicable original rules.

## RULE-GOV-003: Decision Level and Effective Authorization

Status: Active

- R0: read-only exploration or an analysis/plan deliverable without implementation changes.
- R1: implement current SOT with decision not_required. Non-semantic wording/link maintenance still needs integrity checks; touching an SOT path alone does not create a new product decision.
- R2: introduce or change norms, external contracts, persistent-data semantics, or irreversible rules; decision is pending or approved.

Do not reconfirm clear R1 work or complete R2 semantics already explicitly decided by the user. Pending R2 blocks Apply, SOT updates, and completion for that change; separable authorized work continues under its own record. Implementation deviation alone is not a new R2.

Dangerous or materially externally side-effecting actions need explicit authorization. Existing authorization remains valid while action, target, and scope remain unchanged. Preserve a useful summary and stable reference across sessions; an inaccessible chat identifier does not explain authorization. Native tools and project systems enforce actual permissions; P2T2C records are not a runtime interceptor.

Approved R2 binds the current SOT path and SHA-256 and references the explicit decision. List all affected sources in prose; one truth_ref/digest validates only that file, not every rule.

## RULE-GOV-004: Current Rules and Durable Decisions

Status: Active

Keep unique stable RULE-* identities. Store durable DEC-* rationale in the owning SOT, limited to the current choice, applicability, and necessary reasoning. Update current rules in place instead of appending conflicting patches.

Old rationale and superseded content belong in non-authoritative history or Git history; active exceptions remain discoverable in current SOT. One-time action authorization, progress, and actual check results belong in the relevant work record, not permanent business rules. Do not create new active ADRs.

Keep Rule/DEC identities, references, and the manifest intact. Writing style is not a separate approval gate.

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

## RULE-GOV-014: Model Autonomy and Correct Stopping

Status: Active

The model selects retrieval order, decomposition, implementation, debugging, check timing, native delegation, and appropriate review within project constraints. There is no default questionnaire, per-step approval, fixed TDD script, reviewer chain, or per-step proof. Optimize for one person and AI delivering quickly and reliably. Keep overhead proportional; do not require separate method justifications or check reports.

- Ordinary compilation, test, or tool failures allow diagnosis, authorized repairs, and affected reruns. Known failure blocks completion, not automatically a new product decision.
- Further attempts need new evidence, a new hypothesis, or changed conditions. Do not expand checking without cause after the agreed outcome is achieved.
- Stop affected actions for unresolved semantics, missing dangerous-action authorization, user-edit overwrite risk, or missing necessary environments. Record the next step while preserving independently authorized work.
- Parallel writes require clear non-overlapping ownership and one delivery owner. Local passes do not replace necessary integrated validation.
- Explicit project methods and engineering gates remain binding. Legacy obligations do not change with the new core.

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

## RULE-GOV-016: Minimal Active Records and Compatibility

Status: Active

| Case | Active artifacts |
|---|---|
| R0 | No mandatory workflow artifact |
| Supported clear simple R1, compact preferred by the model | One proposal v2 |
| Other R1 or any R2 | proposal v1 + design v1 + tasks v1 |

Compact requires a clear goal and acceptance, sufficient existing SOT, known impact and dependencies, no separately necessary architecture/migration/compatibility design, and recoverable state in a short record. The model judges suitability without line/file/time thresholds or asking the user to select templates. Unsupported consumer integration uses standard while still simplifying reading, execution, and checks.

SP paths are docs/proposals/SP-YYYYMMDD-short-title.md. Standard docs/specs/<NNN-short-title>/ contains exactly design.md and tasks.md. Do not compress existing standard work; completed records remain in place. Compact creates no placeholder specs: proposal schema_version is 2, shape is compact, work_status owns execution state, and specs_ref is none. R1 truth_ref/truth_digest remain none; cite applicable SOT in prose.

Compact prose may use paragraphs, lists, or existing project tables; only stable front matter and Completion have fixed structure. A controlled Tasks section is optional; if present, validate checkboxes and deferrals without treating fenced examples as tasks. Preserve standard v1 fields and sections.

Expand only active compact into v1 standard when complexity or R2 semantics require it. Keep the SP path/ID, progress, and valid checks. Move necessary design and execution state to their owning files; unresolved new semantics remain pending. No reverse compression, legacy conversion, or completed reopening.

## RULE-GOV-017: On Demand Context and Continuation

Status: Active

Entry points locate the version, work identity, authority, and necessary boundaries. The model selects applicable original clauses, definitions, exceptions, and dependencies. Existing unnumbered SOT still requires relevant sections; broaden reading for uncertainty or conflict. No default rereading of every entry point or entire matching file on each step.

Reuse still-valid content. Refresh affected context when goals, branches, related SOT, dependencies, or workspace content change. Manifests, indexes, and summaries locate authority, not another manually maintained business specification.

Persist necessary next actions, pending decisions/blockers, branch/code state, unsynchronized work, and evidence/environment limitations in compact SP or standard tasks. Omit empty handoffs. Use native session capabilities rather than a separate state service. A record does not synchronize code or local evidence; never implicitly commit/push, and report missing required validation environments honestly.

## RULE-GOV-018: Real Acceptance and Project Engineering

Status: Active

Projects define required tests, CI, device acceptance, and release obligations. The model selects sufficient checks based on impact, without full regression after every step or invented tests for low-impact reversible text edits. Reuse applicable results; relevant changes or new failures trigger affected rechecks. Observable outcomes must be clear but may use paragraphs, lists, or existing project records, not a mandatory six-column matrix. Before reusing results, confirm relevant code, dependencies, configuration, environment, and originals remain applicable. Otherwise rerun or report unverified scope. Zero matched tests never count as a pass.

Record actual methods, coverage, checked state, and sources without copying long logs or forcing commits. Explain not-run, inapplicable, and stale results in prose; do not extend v1 Tests enums. Unmet necessary acceptance or stale evidence must set Known blockers: present; standard also retains unfinished obligations. Never silently narrow scope at completion.

Verify and independent review depend on impact. Absence alone does not block, but known failed tests or unresolved Critical findings must be recorded and block completion. Fields and Archive do not independently prove product correctness; project checks and behavioral evaluation detect missing or false declarations.

Archive runs no tests, review, CI, or release smoke. P2T2C release checks run explicitly for this framework release, not on ordinary consumer tasks.

## RULE-GOV-019: Completion and Safe Archive

Status: Active

Compact and standard share the six existing Completion fields and v1 enums: Tests, Verify, Known blockers, Dangerous operations, Authorization ref, and Summary. Archive requires:

- Approved SP with a non-pending decision; ready design for standard.
- One in_progress execution state, no controlled unfinished tasks, and an explicit decision reference for deferrals.
- Tests is not failed, Verify is not critical, and Known blockers is none.
- Dangerous operations is not pending; approved actions carry an authorization reference.
- Summary is not pending, and an active R2 binding matches the current file and manifest.

Preserve archive --spec arguments and JSON. archive --proposal resolves the real main record without fictional tasks/design paths for compact. Safely update only compact work_status or standard tasks.status. Completed records are idempotent and are not rebound or reopened by later SOT changes.

The model maintains completion fields rather than asking the user to fill forms. Normal closure invokes Archive once and reuses its document checks, without preceding structural, readiness, and repository-wide validation. Those tools serve diagnosis, maintenance, or explicit project requirements. Structural valid does not mean ready to archive. Targeted and global validation share rules for the same mode. The core checks explicit declarations and references, not every natural-language obligation. Archive creates no receipt, sidecar, or CR and runs no project commands. Before/after validation, concurrent-edit protection, and interruption recovery are required. Project-owned cleanup reports separately after core success.

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
- Template rollback targets a runtime that cannot read the layout before restoring a compatible document layout.

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

## RULE-GOV-024: SOT Content Governance

Status: Active

SOT holds current effective rules constraining future implementation or acceptance. Define each business meaning in one authoritative location and reference specific clauses elsewhere. Organize by responsibility and preserve conditions, boundaries, and exceptions. Splits retain Rule IDs, manifests, and references. Current SOT is not a task log or one-time authorization history.

Templates advise writing, not fixed word counts, heading order, or style gates. The model identifies duplication and organizes content as needed without changing semantics under the guise of cleanup. Whole-repository cleanup is not a prerequisite for each task or this release.

## RULE-GOV-025: Document Operations and Recovery

Status: Active

create generates mechanical scaffolding. Omitting the shape retains standard for compatibility; the model explicitly selects compact for eligible simple R1. R2 starts pending. expand consumes valid standard candidates prepared by the model without interpreting business prose. Structural validation is read-only. Optional readiness diagnostics share Archive gates and are not another mandatory step. Unknown declared versions fail explicitly.

Creation, expansion, and compact Archive use transactions bound to target identity, paths, and before/after content, preserving concurrent user edits. Expansion takes effect when the original SP switches last. Interruption is recoverable; retries do not allocate duplicate work or overwrite existing files. Recovery, migration, and downgrade must not corrupt shared layout. Unrelated record problems do not become a global prerequisite for targeted work.

## RULE-GOV-026: Trial Upgrade and Release Evidence

Status: Active

Compact in 0.16 remains a candidate capability. The model prefers it for eligible simple R1 in supported integrations and uses standard otherwise. Release validation focuses on changed functionality, content protection, compatibility, and claimed consumer support; reuse valid evidence. Long-term efficiency studies, fixed sample counts, every tool, and cross-device trials are not prerequisites for ordinary delivery or adopting simpler methods. Make no unsupported platform or speed claims; resolve actual current failures.

Ordinary upgrades preserve project-owned configuration, SOT, active records, and legacy bytes. Returning to a layout-compatible runtime, such as standard v1 on 0.15, does not require undoing an already compatible layout; unfinished migration still requires recovery. Supported downgrade paths check target format capabilities and unfinished transactions before replacing runtime files. Reject incompatible v2 records, including completed ones, with their paths rather than converting them. Failed-install rollback restores only managed installation state and preserves user additions.

## DEC-GOV-020: Goal Driven Autonomy and Controlled Compact Trial

Status: Active
Date: 2026-11-09
Supersedes: DEC-GOV-017 for new core work where stated

Decision: Follow the user's 0.16 implementation request and subsequent explicit direction to enable fast, reliable collaboration between one person and AI without workflow-induced slowdown. Center goals, real outcomes, necessary decisions, and minimal continuation. The model owns methods and prefers one record for eligible simple R1 when integration supports it. Preserve standard v1 and legacy compatibility. Avoid repeated closure checks and mandatory long-term comparative trials; complete impact-appropriate checks, preserve user content, and disclose unverified scope. Internal safeguards do not become everyday approval steps.

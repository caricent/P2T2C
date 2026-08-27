# P2T2C_GOVERNANCE - Authoritative Workflow Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-08-26

Authority: P2T2C risk and execution-shape routing, Truth boundaries, human gates, work batches, context layering, machine evidence, verification repair, drift handling, execution methods, install/upgrade safety, and bilingual release rules.

## RULE-GOV-001: Five Governance States and Three Runtime Loops

Status: Active

Rule:

P2T2C retains five governance states:

```text
Intent Admission -> Risk Routing and Truth -> Work Batch Execution -> Verification and Repair -> Drift and Closure
```

At runtime, an Agent combines them into three continuous loops, normally driven by the same controller without five prompt or Agent handoffs:

1. `Admission + Routing`: intent admission, risk, execution shape, Truth discovery, and Gate A.
2. `Planning + Execution`: a shape-appropriate work batch and implementation.
3. `Verification + Repair + Drift + Closure`: verification selection, at most two repair rounds, review, drift handling, and evidence projection.

- Input may be a user instruction, Issue, or optional `SP-*`.
- Continue by default when intent is clear and conflict-free; one controller may traverse every state in one session.
- After context compaction or an Agent handoff, recover from file-based briefs, diffs, machine evidence, and Git state rather than chat memory.
- One work batch may contain multiple related tasks serving one goal and accepted as a whole.

Validation:

- `make check`
- Bilingual stable enums, CPK v3, machine-evidence, and artifact-matrix contracts pass.

Stop the line if:

- A new workflow path is required, or neither risk nor execution shape can be classified.

## RULE-GOV-002: Truth Boundary

Status: Active

Rule:

Business rules belong only in `docs/sot/**`. ADRs explain why. SP, CPK, work, legacy spec/plan/tasks, prompts, run ledgers, tests, code comments, and chat cannot be the only source of a business rule.

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

## RULE-GOV-003: Risk, Execution Shape, and Human Gates

Status: Active

Rule:

Risk determines Truth authority and human gates:

- `R0`: refactoring, tests, docs, CI changes, read-only exploration, or restoring behavior explicitly defined by Truth.
- `R1`: implement behavior already covered by current Truth; create a CPK v3 and do not change Truth.
- `R2`: change Truth, ADRs, external contracts, persistent data semantics, security, privacy, permissions, or irreversible operations; create a complete CPK v3.

The orthogonal `execution_shape` determines decomposition, collaboration, and persistent-document intensity:

- `spike`: bounded, disposable exploration that ships no production or Truth change; upgrade to `bounded` or `architectural` and reroute risk before retaining a behavioral change.
- `bounded`: a clear impact surface accepted as one work batch.
- `architectural`: cross-boundary work requiring a task DAG, file ownership, or staged integration.

Shape may only upgrade `spike -> bounded -> architectural`; it cannot be downgraded to avoid evidence or review. Risk is also rerouted upward when new impact is discovered.

Gate A controls only undecided R2 semantics. If the current instruction already decides complete semantics, record `gate_a: satisfied` without duplicate approval. While pending, only safe read-only `exploration` events that cannot commit semantics are allowed; no Truth Patch, implementation write, or close.

When implementation clearly violates current Truth, the Agent corrects implementation and re-verifies by default without Gate B. Gate B triggers only when accepting the drifted implementation and changing Truth is proposed; accidental implementation cannot become Truth without that decision.

Validation:

- R1/R2 CPK uses the v3 front matter in `docs/change_packs/CPK_TEMPLATE.md` and declares `risk` and `execution_shape`.
- An R2 CPK with `gate_a: pending` has no applied Truth Patch or shippable implementation.
- Shape/risk upgrades enter `route` events. A resolved Gate B enters a `gate_b` event, and `gate_b_decision`, `gate_b_ref`, and `truth_patch_ref` link the human decision to the Truth Patch.

Stop the line if:

- Undecided R2 semantics lack Gate A.
- Accepting implementation and changing Truth lacks Gate B.

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
- Stable paths, risk values, execution shapes, status values, front matter fields, and script behavior remain aligned.
- The repository root is only the language selector and aggregate check surface.

Validation:

- Root `make check` runs both release checks and the release parity check.
- Checksums and smoke tests pass for both roots.

Stop the line if:

- Stable contracts or managed paths diverge between release roots.

## RULE-GOV-007: Installed Work Surface

Status: Active

Rule:

The installed daily work surface is `docs/` and `specs/`. Internal prompts, skills, scripts, templates, migrations, run ledgers, and metadata live under `.p2t2c/`. `.p2t2c/runs/**` is gitignored runtime state, not Truth or an install asset.

Validation:

- Install and upgrade smoke tests.

Stop the line if:

- Install or upgrade overwrites a project-owned file or packages a run ledger as a release asset.

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

## RULE-GOV-014: Adaptive Execution Methods and Agent Autonomy

Status: Active

Rule:

P2T2C is the control layer for decision, risk, Truth, gates, and closure. The `p2t2c-adaptive-v2` method layer may refine intent and prescribe execution discipline, but cannot define business behavior, replace Truth, alter source priority, or bypass Gate A/B.

- Automatable R1/R2 behavior defaults to test-first work. A test first states which production defect would make it fail; expected values cannot be derived from the code under test. Script, prompt, and skill changes prefer consumer behavior tests and use a mutation check when applicable. Generated output, pure configuration, exploration, and impractical automation record an exemption and alternative evidence.
- Every verification repair starts with root-cause investigation and a falsifiable hypothesis. Both repair rounds restore the original implementer; re-review covers only the original finding and fix diff. A third attempt stops for architecture, Truth, scope, or external-environment assessment.
- Bounded R1 production code receives one independent comprehensive review. Architectural R1 and every R2 receive ownership-batch reviews plus a global review on the integrated tree; security, permission, or migration R2 work adds a specialist review. Every reviewer differs from CPK `implementer`; every required review has zero Critical, Important, and Minor findings before closure.
- Read-only exploration may be fully parallel. Writes are parallel only with disjoint file ownership, an explicit isolated baseline, and one integration controller. Only the controller may spawn Agents; implementers and reviewers cannot recursively fan out.
- Homogeneous independent microtasks sharing an acceptance surface are batched into one dispatch and review; the reviewer still checks each brief item.
- Sub-Agents explicitly select fast/standard/strongest capability and reasoning tiers. Waiting is bounded and event-driven; do not wait while executable work remains.
- With `isolation: auto`, prefer host-managed isolation. Create/request a worktree only for R2, parallel, or explicitly isolated work; stop and list content instead of deleting a worktree with untracked or uncommitted files.

Validation:

- CPK, work, machine events, and evidence projections record applicable method checkpoints, role identities, ownership, and baseline.
- Required review binds the reviewer base/head SHA and final tree SHA.

Stop the line if:

- A method artifact is used as the sole source of a business rule.
- A required review, root-cause investigation, isolation boundary, or method exemption is missing.
- An implementer/reviewer recursively spawns Agents or parallel writes overlap ownership.

## RULE-GOV-015: CPK v3, Machine Evidence, and Verification Configuration

Status: Active

Rule:

v0.14 trials `methodology.profile: p2t2c-adaptive-v2` with `methodology.enforcement: advisory`. New work may be promoted to `required` only after a real A/B behavior eval meets the declared efficiency targets and quality non-inferiority, followed by a separate human promotion decision. Passing deterministic fixtures cannot substitute for that evidence. Historical CPK, spec, plan, tasks, and CR artifacts are not migrated or rewritten, and an unrun real eval cannot be claimed as passing.

New CPKs use `schema_version: 3` and declare execution/method/implementer, Truth Patch ref+digest, Gate B, ownership batches, and legacy-startup fields. R1 Truth ref/digest is `none`; R2 references one existing `docs/sot/**` file whose SHA-256 matches. Architectural `ownership_batches` is a comma-separated unique-ID list; bounded/spike uses `none`. Only architectural `legacy_startup_evidence: true` retains the old trio. Spike cannot apply or close.

During execution, gitignored `.p2t2c/runs/<work-id>/events.jsonl` is a work-isolated temporary ledger. Implemented event types are exactly `exploration`, `verification`, `tdd_red`, `tdd_green`, `tdd_exemption`, `mutation`, `route`, `isolation`, `repair`, `gate_b`, and `review`. Type-specific data records:

- command, exit code, verification profile, and output summary;
- TDD RED/GREEN or a reasoned exemption consistent with `tdd_policy`;
- worktree, branch, and baseline state;
- structured route and Gate B state; repair records exact `repair_round`, `hypothesis_digest`, `implementer`, `failure_digest`, `fix_base_sha`, `fix_head_sha`, and `fix_diff_digest`;
- reviewer identity, `batch|global|specialist|re_review` role, ownership `batch_id`, base/head SHA, findings, and verdict; re-review links the original finding scope.

Handwritten claims cannot replace machine events. Events/receipt use `contract_digest`; a contract or Truth-digest change invalidates old events. In one lifecycle, close projects, runs the normal checker, confirms target and receipt, then cleans the ledger. Any failure restores the original CPK/CR and keeps run state; no partial closure remains. `evidence_trust: local_consistency` proves non-adversarial local consistency only, not signature or remote attestation.

Project configuration must provide verification profiles and `verification.path_mapping`. Every changed path must match; no mapping, missing command ID, or profile-config-digest mismatch is a core hard failure with no fallback. R2/multi-Agent primary requires full, governance change additionally requires governance, and both complete sets pass on one final tree.

Advisory relaxes only unpromoted method completeness. Gaps enter receipt `evidence_warnings`; `methodology_enforcement` and `evidence_completeness` show advisory/incomplete, and the Agent cannot claim method-complete, warning-free completion, or promotion readiness. Schema, gates, Truth ref/digest, path mapping, contract/final tree, consistency, and atomic closure remain hard gates.

Receipt also projects `gate_a`, `truth_patch_digest`, `ownership_batches`, `legacy_startup_evidence`, `path_mapping_digest`, `matched_profiles`, `matched_paths_digest`, `baseline_sha`, and `remaining_risk_ref` so routing, Truth, ownership, path verification, and residual risk are reviewable.

R0 has no CPK. Only audit/residual-risk policy invokes close with verification profile, remaining-risk-status, and `--remaining-risk-ref <none|ref>` for automatic CR. Recorded status needs a non-none ref; none status needs ref=none. Spike never closes.

Validation:

- The checker parses JSONL and rejects stale SHA/contract digest, failed final-tree verification, identical implementer/reviewer identity, missing review roles, and any nonzero finding.
- Closed CPK/CR artifacts bind 100% of applicable verification and required reviews to the final diff/tree.
- Advisory projects and historical v2 artifacts remain valid with actionable guidance.

Stop the line if:

- Required mode closes without applicable machine evidence; advisory mode may warn but cannot be described as promoted.
- R2 or multi-Agent work lacks final-tree full, or governance change lacks the governance set on the same final tree.
- An unprojected ledger is deleted or handwritten text is presented as execution evidence.
- Non-atomic close leaves a partial target, or advisory warnings are presented as complete.

## RULE-GOV-016: Artifact Matrix and One Managed-file Inventory

Status: Active

Rule:

Risk and execution shape jointly determine persistent artifacts:

| Scenario | Required persistent artifacts |
|---|---|
| R0 | No P2T2C doc by default; automatically create a minimal CR only when `p2t2c.r0.audit_mode: true`, or residual risk exists and `closure_on_residual_risk: true` |
| bounded R1 | One CPK v3 containing intent, Truth references, acceptance, strategy, and automatically projected closure evidence |
| architectural R1 | CPK v3 + one `work.md`; project closure evidence into the CPK |
| bounded R2 | Complete CPK v3 + Truth Patch + automatic CR; create an ADR only for a decision needing durable explanation |
| architectural R2 | Complete CPK v3 + Truth Patch + `work.md` + automatic CR; create an ADR only for a decision needing durable explanation |

A spike creates no process doc and ships no retained change. New bounded work cannot contain spec/plan/tasks. Only an architectural CPK with `legacy_startup_evidence: true` may retain the old trio as startup evidence; it is not a new-process precedent.

`work.md` records only interfaces, data flow, task DAG, ownership, integration order, verification, and drift. It does not repeat CPK intent/Truth or define business rules.

`.p2t2c/managed-files.txt` is the only managed-path inventory. `.p2t2c/manifest.yaml` stores only the metadata pointer to that inventory. The checker, installer, upgrader, and checksum generator consume `managed-files.txt` rather than separate hard-coded lists.

Validation:

- Artifact-matrix fixtures cover all three risks and shapes, audited R0, and residual-risk R0.
- Install, upgrade, checksum, and checker report the same managed-file set.

Stop the line if:

- New bounded R1 work creates the legacy trio or a separate CR by default.
- R2 closes without an automatic CR.
- A managed-file consumer bypasses `managed-files.txt` or uses a divergent path list.

## RULE-GOV-017: Minimal Deterministic Context and Cold Evidence

Status: Active

Rule:

Without changing `p2t2c-adaptive-v2`, R0/R1/R2, execution shape, Gate A/B, the two repair rounds, or required review, v0.14.1-A layers Agent context as follows:

- `Hot`: the compact AI entry, current route/contract, exact Truth ref+digest, current CPK/work pointers, and next legal action; always available.
- `Warm`: the one phase skill for the current runtime loop, task DAG, latest failure, open finding, and recovery checkpoint; loaded only for the current phase.
- `Cold`: raw events, complete failure output, historical CPK/CR, schemas, Governance History, references, and migration detail; read only for audit, failure diagnosis, or conflict investigation.

Hot/Warm summaries cannot replace exact Truth text. A context capsule identifies its sources with manifest/config/contract/Truth/tree digests; a change in any binding makes the capsule stale and requires regeneration. Truncation cannot hide a missing rule.

Managed commands provide bounded, versioned, machine-readable views:

```text
p2t2c context --phase admit-route|execute|verify-close [--work-id ID] --json
p2t2c status --work-id ID --json
p2t2c evidence summary --work-id ID --json
```

Risk signals from `context` are non-authoritative hints, not substitutes for Agent routing, CPK, or a gate. `status` and `evidence summary` are read-only aggregations and omit raw intent, events, command output, and chat by default. Five governance states still run through three runtime loops, but the AI entry lazily loads only the current one of the `admit-route`, `execute`, and `verify-close` phase skills. The five legacy prompt paths remain as compact compatibility pointers.

The Truth manifest contains locator-only rule/topic/path/digest data instead of Governance prose. Managed defaults and a project-owned config override form one deterministic effective config. Historical full config remains valid and upgrade does not rewrite it. Missing override values may inherit defaults, but an explicitly declared malformed section/profile is a hard failure, never a silent fallback.

Close stores raw event JSONL in a content-addressed cold sidecar:

```text
docs/closure/evidence/EV-<work-id>-<source_digest>.jsonl
```

The sidecar contains frozen events only, not the receipt. Closure receipt v2 binds its safe relative path, SHA-256, and event count. The CPK/CR marker projects only one receipt-v2 line, so default reading no longer loads raw events. Historical inline events plus receipt v1 remain valid byte-for-byte without migration or rewrite. v2 `tree_excludes` binds exactly `.p2t2c/runs/**`, the evidence target, and the evidence sidecar; v1 retains its historical two-item contract.

Close freezes the ledger, securely creates and offline-validates sidecar/target candidates, installs the non-overwriting content-addressed sidecar first, atomically switches the target second, and finally runs the normal checker. Any failure restores the original target, removes a sidecar newly created and unreferenced by this transaction, and retains run state. The `local_consistency` trust boundary does not expand: it claims no digital signature, remote-execution authenticity, or resistance to simultaneous tampering.

When a command event exits nonzero, its complete raw output is written only to gitignored `.p2t2c/runs/<work-id>/outputs/<event-id>.log`, with directory mode `0700` and file mode `0600`. The Agent automatically receives only a sanitized tail of at most 80 lines and 16 KiB, plus safe path and digest. Failed close retains logs; successful close deletes them with run state. Raw output never enters the persistent sidecar, receipt, or default context.

Validation:

- Context commands conform to stable JSON schemas, remain strictly bounded, and do not leak raw intent/event/output text.
- New R0/R1/R2 closures validate receipt-v2 sidecar digest/count/path/final-tree binding; historical receipt-v1 regression remains green.
- Symlink, hardlink, traversal, substitution, concurrent-close, and rollback fixtures cover sidecar, outputs, candidates, and target.

Stop the line if:

- A capsule summary is treated as Truth, or a stale binding remains in use.
- Receipt v2 lacks a safe sidecar reference, its digest/count differs, or a failed close leaves a new target referring to incorrect sidecar bytes.
- Complete command output is projected into CPK/CR or default Agent context.

## RULE-GOV-018: Semantically Equivalent Execution-engine Efficiency

Status: Active

Rule:

v0.14.1-B removes repeated parsing, duplicate commands, and unnecessary serial waiting only. It does not weaken the Truth, gate, review, repair, final-tree, or evidence requirements in RULE-GOV-003, 014, and 015.

- The checker uses one process core and parses each config, CPK/work/CR, Truth, sidecar, and front matter at most once per check; shell remains only as a compatibility entry.
- Only closed, successful, content-addressed historical artifacts may be cached across runs. A cache key binds at least artifact/CPK/sidecar digests, schema/helper/checker digests, effective-config digest, and Git object-store identity. Active work, pre-close proof, new receipts, global Rule uniqueness, and safe-path checks cannot be omitted through cross-tree cache; any key change is a miss.
- `p2t2c verify --work-id <id> --profile <profile>` parses effective config once, establishes final-tree binding, runs the profile's stable command IDs, and appends aggregated machine events. Only commands declared read-only may run concurrently in one `parallel_group`; any command changing tree/HEAD or failing fails the verification batch.
- Commands with exactly identical expanded argv may run once through a configured `covers` relationship. A coverage event records every covered profile, command ID, and profile-config digest; the checker re-expands them and requires identical argv digests. A matching name, similar intent, or handwritten claim cannot establish coverage.
- In one process, close fully validates ledger/tree/path mapping/review/verification once, creates a proof bound to checker/helper/schema/effective-config/contract/final-tree/evidence digests, then validates the candidate. The post-install normal checker may reuse already-proven parse results, but still checks the new target/sidecar, global invariants, and every proof binding. Any digest/tree/path mismatch hard-fails rather than degrading to handwritten `Pass`.
- Release smoke is split into `contract`, `security`, `transaction`, `migration`, `locale`, and aggregate `all`. Daily feedback runs suites selected by changed paths. Behavior-identical EN/CN core executes once, while locale/install/migration cases may run in isolated temporary directories concurrently. Every release and this R2 final closure still runs one complete `smoke all` on the same final tree without removing existing negative coverage.

These optimizations are replaceable execution strategies, not a new Agent-policy experiment. v0.14.1 does not add dispatch thresholds, new model/effort escalation, review capsules, compaction policy, or review-deduplication experiments. Existing Agent autonomy, review, and repair boundaries in RULE-GOV-014 remain unchanged.

Validation:

- Old and new checker semantics match on the same fixture set; cache hit/miss, corrupted-cache, active-work, and global-invariant fixtures pass.
- Every required batch-verification command ID has a same-final-tree direct or equivalent coverage event; forged covers and argv/config-digest mismatch are rejected.
- Receipt, stop conditions, and rollback remain identical after close deduplication; final `smoke all` runs exactly once and passes completely.

Stop the line if:

- Cache/proof/coverage omits a strong binding, or concurrent commands change tree/HEAD.
- A partial suite is presented as final release evidence, or EN/CN deduplication hides a locale difference.
- Execution-engine optimization changes gates, reviews, repair limit, Truth authority, or final-tree requirements.

## Work Batches and Execution Docs

- R0 and spike work execute without `specs/{feature}/` by default.
- Bounded R1 uses only CPK v3; only architectural R1/R2 adds `work.md`.
- `work.md` references CPK and Truth and records the task DAG, file ownership, integration, and batch acceptance.
- Legacy `spec.md`, `plan.md`, and `tasks.md` templates remain for historical projects without migration. The 014 trio is evidence that the v0.14 R2 change began under v0.13.

## Verification, Autonomous Repair, and Closure

- Diagnose root cause before repairing the first verification failure; allow one unchanged retry for a clear environment failure.
- Allow at most two repair rounds for the same failure, restoring the original implementer; then scoped re-review findings and fix diff.
- Changed assertions cite Truth, CPK, or acceptance evidence.
- The Agent automatically backfills CPK/work Execution Doc Drift.
- Correct clear Truth violations and re-verify; trigger Gate B only to accept implementation and change Truth.
- R1 projects closure evidence into CPK; R2 creates an automatic CR; R0 creates a minimal CR only when audit or residual-risk policy requires it.

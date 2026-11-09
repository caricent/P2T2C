# P2T2C Core Workflow

P2T2C means Proposal-to-Truth-to-Code. Version 0.16 helps one person and AI deliver quickly and reliably: agree on the goal, work continuously with necessary checks, then record and deliver. The model chooses methods, tools, and records without reconfirming clear decisions.

## Everyday Work

Read applicable original clauses, exceptions, and dependencies, not every matching file or every entry on each step. Repair ordinary failures within authorization. Ask the user only for missing consequential decisions or action authorization. Report missing necessary environments and retain useful continuation.

Match checks to impact. Reuse applicable results; relevant changes or new failures trigger affected reruns. Avoid full regression after every step and invented tests for low-impact text edits. Necessary project checks remain binding; known failures and missing necessary acceptance cannot be called complete.

## The Model Maintains Records

- Prefer compact v2 for eligible clear simple R1 when runtime and consumer support exist: only docs/proposals/SP-*.md. Explain the goal, actual result, and remaining issues without a mandatory task list or acceptance matrix.
- R1 needing separate important design and all R2 retain standard v1: SP plus docs/specs/<NNN-change>/{design.md,tasks.md}. Unsupported integrations also use standard.
- R0 creates no workflow artifact. Preserve existing standard and legacy identities and formats; expand active compact only when needed.

The model may use create for mechanical fields. This is one example for simple work, not a template choice for the user. Omitting --shape retains standard for compatibility.

```bash
.p2t2c/bin/p2t2c create --id SP-20261109-small-fix --shape compact --risk R1 --json
```

R2 selects standard and supplies --truth-ref; its initial decision is pending. Record a complete existing decision and update applicable SOT before implementation without asking for approval again.

## Archive Once for Normal Closure

After accurately updating completion information, use the project's existing Archive wrapper, or the core command when no wrapper exists:

```bash
.p2t2c/bin/p2t2c archive --proposal SP-20261109-small-fix --json
```

Existing standard may instead use archive --spec NNN-change; choose one selector. Archive includes document checks, so do not precede it with validate-docs, --ready, or repository-wide validation. It reruns no project tests, review, CI, or release smoke and produces no additional evidence report. Missing optional Verify alone does not block; missing necessary acceptance sets Known blockers: present.

Compact updates SP.work_status; standard updates tasks.status. Completed records support idempotent retry and are not reopened by later SOT changes. Tools validate declarations and references; actual correctness comes from outcomes and necessary project checks.

## On Demand Maintenance

validate-docs --proposal locates a record; --ready diagnoses Archive blockers; global validate-docs serves repository maintenance or explicit project checks. They are not an everyday command sequence.

For expansion, the model prepares proposal.md, design.md, tasks.md, and source.sha256 for the original SP, then calls expand --proposal SP-... --prepared <directory>. --source-digest is an alternative. Preserve identity, progress, and user edits. Retry the original command after interruption, using recover --proposal when needed. Only active compact expands; new semantics still need a clear decision.

After checking external evidence, a project wrapper may pass the main record digest through archive --record-digest to protect against concurrent edits. Targeted validation returns record_digest and source_digest. These internal details are not user forms or proof that code passed tests.

## SOT and Upgrades

Current rules live only in docs/sot/**. Define each rule once and update it in place as needed. Keep progress, history, and one-time authorizations in work records or history. Writing and length guidance is advisory, without style gates or whole-repository cleanup requirements.

This build remains a candidate; compact depends on actual consumer support. Long-term efficiency statistics and cross-device trials are not everyday delivery conditions. Disclose unverified scope honestly.

Ordinary upgrades preserve project-owned files and legacy evidence without moving documents. Use docs-migrate only when needed. Supported downgrade paths reject incompatible records, including completed compact, before replacing runtime files; never fake a downgrade by editing schema numbers. Existing 0.14.x CPK/run work continues through its original legacy engine.

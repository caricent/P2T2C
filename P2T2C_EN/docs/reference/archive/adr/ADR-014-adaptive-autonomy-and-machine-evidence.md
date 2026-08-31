# ADR-014: Adaptive Autonomy and Machine Evidence

Status: Accepted
Date: 2026-08-26
Change Pack: `docs/change_packs/CPK-20260826-adaptive-v2.md`
Truth Patch: `docs/sot/governance/P2T2C_GOVERNANCE.md`
Truth Patch SHA-256: `a7d1be7c1869ab4ef5025c507e4673a3c46eb524fc35b038235318e6e5a04012`

## Context

v0.13 preserved the correct Truth, R0/R1/R2, Gate A/B, and fresh-verification boundaries, but R1/R2 always created CPK, spec, plan, tasks, and CR, repeating goal, Truth, verification, and method evidence. The checker relied mainly on Markdown claims and could not prove that commands, reviews, and final code described the same tree.

Superpowers v6.2/v6.3 demonstrated work-isolated temporary ledgers, restoring the original implementer, scoped re-review, spike/bounded/architectural tiers, homogeneous microtask batching, no recursive fan-out, file-based handoffs, and event-driven waiting. P2T2C can translate these into execution discipline without surrendering its Truth authority and human gates.

## Decision

1. Retain R0/R1/R2 as the Truth-authority axis and add `execution_shape: spike | bounded | architectural` as the execution-intensity axis, with upward-only upgrades.
2. Retain five governance states but combine runtime into three continuous Agent loops without mandatory five-step handoff.
3. Make R0 zero-document by default; bounded R1 uses one CPK v3; architectural adds one work; R2 retains Truth Patch and creates CR automatically. Create an ADR only when durable explanation is needed.
4. CPK binds Truth digest/ownership/legacy. Ledger adds exploration/re_review; receipt projects `methodology_enforcement`, `evidence_completeness`, `evidence_warnings`, mapping, baseline, and risk ref.
5. Adopt adaptive review, parallel, model-routing, and two-round repair boundaries. Only the controller may spawn Agents; correct clear Truth violations automatically, and trigger Gate B only to accept implementation and change Truth.
6. Make `.p2t2c/managed-files.txt` the only managed-file inventory consumed by checker, install, upgrade, and checksum generation; `.p2t2c/manifest.yaml` stores only its pointer.
7. Advisory still hard-gates Gate/Truth digest/path mapping/contract/final tree/atomic close. Method gaps are structured warnings with incomplete completeness. Promote required after real A/B plus human decision.

## Upstream Practices Not Adopted

- No uniform human approval before every task; Gate A remains limited to undecided R2 semantics.
- Spec or plan cannot override SoT, and Superpowers is not a runtime dependency.
- No five-round repair, parking Important findings, mandatory worktree per task, or one Agent per Task.
- A reviewer may reuse evidence from the same tree, but closure still requires fresh final-tree verification.

## Consequences

- Bounded work removes repeated documents and prompt handoffs while complex/R2 work retains strong audit controls.
- New schema/CLI requires verification profile+command ID and close profile. Runner is quiet by default with explicit show-output. Close failure rolls back target and retains run state.
- New and existing projects stay advisory through trial and promotion decision; after approval, existing projects still explicitly opt into required. Historical v2 artifacts and 013 evidence are not migrated or rewritten.
- Deterministic fixtures prove interface behavior only. The real Agent A/B has not run, so targets cannot be claimed. Local consistency is also not adversarial tamper proof.

## SoT Projection

- RULE-GOV-001, 003, 014, 015, and 016 in `docs/sot/governance/P2T2C_GOVERNANCE.md`.

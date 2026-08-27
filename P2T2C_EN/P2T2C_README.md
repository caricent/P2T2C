# P2T2C Adaptive Risk-Routed Workflow

P2T2C means **Proposal-to-Truth-to-Code**. v0.14 keeps Truth, R0/R1/R2, Gate A/B, and final fresh verification while scaling workflow ceremony to the shape of the task.

```text
Admission + Routing -> Planning + Execution -> Verification + Repair + Drift + Closure
```

The AI entry point is `P2T2C_AGENTS.md`.

## Risk and Execution Shape

Risk determines whether AI may change Truth: R0 does not change business behavior, R1 implements existing Truth, and R2 changes Truth/contracts/data/security/permissions. The orthogonal execution shape controls execution and documentation intensity: `spike` is disposable exploration, `bounded` is one-batch work, and `architectural` needs a DAG, ownership, and integration.

| Scenario | v0.14 persistent artifacts |
|---|---|
| R0 | None by default; automatic minimal CR for audit mode or residual risk |
| bounded R1 | One CPK v3 containing closure evidence |
| architectural R1 | CPK v3 + one `work.md` |
| bounded R2 | Complete CPK v3 + Truth Patch + automatic CR |
| architectural R2 | Complete CPK v3 + Truth Patch + `work.md` + automatic CR |

SP is optional. New bounded work rejects the old trio; only architectural + `legacy_startup_evidence: true` retains real old-workflow startup evidence. CPK uses unique ownership IDs and a Truth-Patch SHA-256 bound to one SoT file.

## Machine Evidence

Commands, TDD exemption, route, isolation, repair, Gate B, and independent review enter a gitignored per-work JSONL ledger bound to tree SHA and the CPK contract digest. Closure projects a necessary receipt into R1 CPK or R2/R0 CR and cleans the ledger only after validation. Handwritten Markdown `Pass` or review claims are no longer execution evidence.

Receipt `evidence_trust: local_consistency` describes non-adversarial local consistency only. It is not a signature, remote attestation, or protection against an actor able to rewrite tooling and ledger together.

Every changed path must match path mapping and resolve a configured command ID. R2/multi-Agent requires full and governance change adds governance; missing mapping is a core hard failure.

Example:

```bash
bash .p2t2c/bin/p2t2c_run.sh --work-id CPK-... --event-type verification --verification-profile impacted --command-id p2t2c-check
bash .p2t2c/bin/p2t2c_close.sh --work-id CPK-... --verification-profile impacted
```

Runner is quiet by default and records only summaries/digests. Add `--show-output` explicitly for debugging; chat output is not evidence. Verification resolves only configured profile + command ID and accepts no arbitrary trailing command.

## Quality Guardrails

- Bounded R1 production code gets one independent comprehensive review; architectural R1/R2 gets batch + global review and specialist review when applicable. Reviewer identity differs from implementer, and Critical/Important/Minor are all zero.
- Both repair rounds restore the original implementer and re-review only finding + fix diff; stop before a third round.
- Read-only work may parallelize; parallel writes require disjoint ownership, explicit baseline, and one controller.
- Implementers/reviewers cannot recursively spawn Agents.
- The Agent corrects clear Truth violations and re-verifies; Gate B triggers only to accept implementation and change Truth.

## First Install

```bash
cd /path/to/P2T2C_EN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

v0.14 advisory still hard-gates core evidence. Method gaps project as `evidence_warnings`, leaving `evidence_completeness` incomplete rather than masquerading as complete. Promote required only after real A/B plus human decision.

## Upgrade

```bash
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_EN
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_EN
```

Install and upgrade update only unmodified managed workflow-shell files and preserve project-owned Truth, ADRs, SPs, CPK, spec/work, code, tests, and historical CRs.

## Layout

| Path | Responsibility |
|---|---|
| `P2T2C_AGENTS.md` | AI entry point |
| `docs/sot/**` | Current business Truth |
| `docs/adr/**` | Reasons that need durable explanation |
| `docs/change_packs/**` | R1/R2 CPK v3 |
| `specs/**/work.md` | Architectural execution index |
| `docs/closure/**` | Automatic R2 and conditional R0 CRs |
| `.p2t2c/runs/**` | Gitignored temporary machine evidence |
| `.p2t2c/**` | Prompts, skills, templates, scripts, and upgrade metadata |

# Closure Reports

v0.14 scales closure artifacts by risk and execution shape:

- R0 creates no document by default. It automatically creates a minimal CR only when `p2t2c.r0.audit_mode: true`, or residual risk exists and `closure_on_residual_risk: true`.
- R1 does not create a separate CR; closure evidence is projected into CPK v3.
- R2 always creates `docs/closure/CR-*.md` automatically. `CPK-foo` maps to `CR-foo`.

R0 has no CPK. Only audit mode or residual-risk policy runs:

```bash
bash .p2t2c/bin/p2t2c_close.sh --work-id R0-... --verification-profile impacted --remaining-risk-status recorded --remaining-risk-ref docs/risk/RISK-001.md
```

It creates `docs/closure/CR-*.md` automatically. Spike never closes and must upgrade execution shape first.

With no remaining risk, use `--remaining-risk-status none --remaining-risk-ref none`. Close is atomic: projection or normal-checker failure restores the original target, retains run state, and leaves no half-closed CR.

New CR uses schema v3 / machine_bound / local_consistency; handwritten claims cannot replace receipt. Receipt also projects Gate A, Truth digest, ownership/legacy, methodology enforcement/completeness/warnings, path-mapping digest/matched profiles/paths, baseline, and remaining-risk ref. Advisory warnings make completeness incomplete and cannot masquerade as complete; core consistency remains hard-gated.

The marker of a new v0.14.1 closure contains receipt v2 only. Raw events live at `docs/closure/evidence/EV-<work-id>-<source_digest>.jsonl`. Use `p2t2c evidence summary --work-id <id> --json` for the bounded default view and read a sidecar only for audit/diagnosis. Historical inline receipt v1 is not migrated.

The Agent backfills CPK/work Execution Doc Drift. Clear Truth violations are corrected and re-verified; Gate B triggers only to accept implementation and change Truth.

Historical CRs are not migrated or rewritten.

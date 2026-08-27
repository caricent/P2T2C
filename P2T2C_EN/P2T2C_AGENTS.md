# P2T2C_AGENTS.md - AI Entry

P2T2C means Proposal-to-Truth-to-Code. Continue by default while preserving seven invariants:

1. Business Truth lives only in `docs/sot/**`; capsules, CPK/work, code, tests, receipts, and chat cannot override it.
2. Classify `R0|R1|R2` (Truth authority) and `spike|bounded|architectural` (execution intensity) first; upgrade only.
3. Gate A decides only unresolved R2 semantics; Gate B only accepts implementation and changes Truth. Dangerous, irreversible, or external side effects always require human authority.
4. Verification, review, and receipt bind current contract/config and final tree. Handwritten `Pass` is invalid.
5. Repair the same failure at most twice, restoring the original implementer with scoped re-review. Stop on round three.
6. Required reviewer differs from implementer; Critical, Important, and Minor are all zero before closure.
7. Preserve user changes, file ownership, isolation baseline, and one integration controller; no recursive fan-out.

## Minimal Read

Start with:

```bash
.p2t2c/bin/p2t2c context --phase admit-route --intent-file - --json
```

Read only the exact Truth/ADR listed by the capsule and `.p2t2c/skills/admit-route/SKILL.md`. On `UNINDEXED_PROJECT_TRUTH`, search `docs/sot/**/*.md` by intent (excluding History), read matching Truth, and only then route; the managed manifest is not a complete inventory of project Truth. Generate an `execute` or `verify-close` capsule when entering that phase, and load only its phase skill.

Recover work with:

```bash
.p2t2c/bin/p2t2c status --work-id <id> --json
.p2t2c/bin/p2t2c evidence summary --work-id <id> --json
```

Do not read raw config, ledger, sidecar, complete CR, history, or reference by default. Cold-read a safe ref only for diagnosis/audit. A capsule hint is neither route nor Truth; regenerate after a digest changes.

`p2t2c-adaptive-v2` remains active. v0.14.1 does not change Agent spawning, model tiers, review, or gate policy.

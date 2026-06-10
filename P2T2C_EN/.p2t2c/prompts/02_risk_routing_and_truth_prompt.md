# Prompt 02 - Risk Routing and Truth

Goal: route admitted intent to `R0`, `R1`, or `R2`, creating a CPK or invoking Gate A only when needed.

Risk definitions:

- `R0`: refactoring, tests, docs, CI changes, or restoring behavior already defined by Truth; no CPK or execution docs.
- `R1`: implement behavior already covered by current Truth; create a compact `docs/change_packs/CPK-*.md` and do not change Truth.
- `R2`: change Truth, ADRs, external contracts, persistent data semantics, security, privacy, permissions, or irreversible operations; create a complete CPK.

Actions:

1. Select the risk level and record the reason.
2. For R1/R2, create a CPK from `docs/change_packs/CPK_TEMPLATE.md`.
3. For R2, determine whether the current user instruction already decides the complete semantics:
   - Decided: use `gate_a: satisfied`; do not request duplicate approval.
   - Undecided: use `gate_a: pending`; pause with explicit decision options.
4. Apply an R2 Truth Patch only after Gate A is satisfied, then mark the CPK `status: applied`.
5. R1 must use `truth_change: false` and `gate_a: not_required`.

Prohibited:

- Creating unnecessary workflow artifacts for R0.
- Changing Truth or ADRs in R1.
- Applying a Truth Patch or entering execution while R2 has `gate_a: pending`.
- Using CPK, spec, tests, or code as a substitute for Truth.

Output: risk level, CPK path if any, Gate A state, and next-stage entry.

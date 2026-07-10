# Prompt 04 - Verify and Repair

Goal: run the applicable verification set and autonomously repair failures without changing Truth.

Choose applicable checks:

- Build
- Test
- Lint
- Typecheck
- Governance check

Repair discipline:

- Before the first repair, use `skills/root-cause-debugging/SKILL.md`: retain the full failure, reproduce it when possible, inspect changes and working patterns, trace the source, and state one testable hypothesis.
- Test the smallest repair that addresses the confirmed root cause; do not bundle speculative fixes.
- Allow at most two code or test repair rounds for the same failure.
- Allow one unchanged retry for a clear environment failure.
- A changed test assertion must cite existing Truth, CPK, or spec evidence.
- Do not weaken verification, remove coverage, or change production rules to bypass failure.

If a third repair would be required, stop autonomous repair and return for architecture, Truth, scope, or external-environment assessment.

Pause only when:

- A new semantic decision, dangerous operation, or external permission is required.
- The same failure exceeds the repair limit.
- Repair would change Truth, an ADR, or confirmed CPK scope.

Output actual commands, results, root cause and hypothesis when a repair occurred, repair rounds, reasons for skipped checks, and remaining risks. Do not claim completion without fresh evidence from the applicable verification closure.

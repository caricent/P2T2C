# Prompt 04 - Verify and Repair

Goal: run the applicable verification set and autonomously repair failures without changing Truth.

Choose applicable checks:

- Build
- Test
- Lint
- Typecheck
- Governance check

Repair discipline:

- Diagnose and repair the first failure instead of stopping immediately.
- Allow at most two code or test repair rounds for the same failure.
- Allow one unchanged retry for a clear environment failure.
- A changed test assertion must cite existing Truth, CPK, or spec evidence.
- Do not weaken verification, remove coverage, or change production rules to bypass failure.

Pause only when:

- A new semantic decision, dangerous operation, or external permission is required.
- The same failure exceeds the repair limit.
- Repair would change Truth, an ADR, or confirmed CPK scope.

Output actual commands, results, repair rounds, reasons for skipped checks, and remaining risks.

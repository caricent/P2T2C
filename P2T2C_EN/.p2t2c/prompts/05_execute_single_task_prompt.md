# Prompt 05 — Execute One Task

Goal: execute only the specified Task in `tasks.md`.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Governance reading (RULE-GOV-012): this stage's phase token is `single_task`. Read only the governance Rule Blocks on the `single_task:` line of `.p2t2c/generated/phase_rules.txt`. Do not read all of `P2T2C_GOVERNANCE.md`, and do not read `P2T2C_GOVERNANCE_HISTORY.md`.

Additional reads for this stage:

- Related SoT
- Current feature `spec.md`
- Current feature `plan.md`
- Current feature `tasks.md`

Rules:

- Implement only the user-specified Task.
- Do not implement features outside the Task.
- Do not add rules not defined by Truth.
- Run the Task acceptance command when complete.
- Backfill Actual results in `tasks.md`.
- If the acceptance command fails, do not expand scope to fix other Tasks; stop and report evidence first.

Must stop:

- A key Plan assumption becomes invalid.
- Implementation requires a new rule not defined by SoT.
- Acceptance fails.
- Truth Drift appears.

---

## Task-chain acceptance merging (0.11.0 R1)

Applies to the single_task phase. This is workflow execution discipline, not a business rule.

When consecutive tasks in the same spec all meet the conditions below, the full Acceptance command may be merged into one run at the chain endpoint. Midpoint tasks use compile pass plus that task's minimal local verification as acceptance:

- Same spec; never across specs.
- Same domain object, such as the same Repository, Executor, Calculator, ViewModel, Service, or Module.
- Same-source test suite, and the endpoint task's suite covers the midpoint task assertions.

Every task completion report must explicitly declare one scope:

- `Acceptance scope: single` (default; no merge).
- `Acceptance scope: chain-midpoint` (midpoint task; compile plus minimal local verification only).
- `Acceptance scope: chain-endpoint covering NNN.x-NNN.y` (endpoint task; one full-chain suite run).

Boundaries:

- Merging reduces command invocations only; it does not change the coverage assertions written in `tasks.md`.
- Never merge across specs or domain objects.
- Treat any doubt as `single`.

---

## Failure classification and retry discipline (0.11.0 R2)

Applies to automated test, build, lint, or governance check failures.

The environment-failure keyword allowlist is project-stack extensible. Put project extensions in the project-owned `AGENTS.md` or equivalent AI entrypoint. Common examples (not exhaustive):

- Simulator / device: `CoreSimulator service was invalidated`, `Could not attach to pid`, `No devices are booted`, `Lost connection to testmanagerd`, `Could not find a destination`.
- Container / runtime: `Cannot connect to the Docker daemon`, `OCI runtime exec failed`, `container is not running`.
- Process / port: `address already in use`, `bind: address already in use`, `port is already allocated`.
- Filesystem / permissions: `Cache permission denied`, `Read-only file system`, `EACCES`, `Failed to open`.
- Network: `Connection refused`, `EOF when reading from connection`, `network is unreachable`, `dial tcp:`, `getaddrinfo ENOTFOUND`.

Handling:

- If the allowlist matches, retry at most once; if it still fails, stop and ask a human. Do not chain retries.
- Do not modify production code to mask an environment failure.
- Failures that do not match the allowlist go through R3 triage.

---

## Test triage (0.11.0 R3)

The first action after any test, build, lint, or governance check failure is triage.

Step 1: If the project provides a triage tool, call it first. Tool paths are declared in the project-owned `AGENTS.md` or equivalent entrypoint. If no tool exists, go directly to Step 2.

Step 2: Classify into exactly one of these labels:

- `compile_error`: compile or type-check failure with no unit assertion line.
- `unit_assertion`: unit assertion failure, such as `XCTAssert*`, `expect()`, or `assert*`.
- `sandbox_environment`: matches the R2 environment keyword allowlist.
- `runtime_crash`: tested program or runner crash, hang, or OOM.

Step 3: Handle by class:

- `compile_error`: fix code and rerun the task's minimal suite.
- `unit_assertion`: fix code or test assertion and rerun the task's minimal suite. Test assertion changes must cite the basis (SoT, spec, or Truth source); do not change assertions to bypass a failure.
- `sandbox_environment`: use the R2 single retry or stop.
- `runtime_crash`: stop and ask a human; do not restart the runner and chain retests.

Step 4: Record the result in task Actual with the triage label and retry count, for example:

```text
Actual: Fail (unit_assertion, retries: 1) -> fixed by adjusting accumulator init; re-ran make test-one; Pass
Actual: Fail (sandbox_environment, retries: 1) -> re-ran make test-one; Pass
Actual: Fail (runtime_crash, retries: 0) -> paused, human review requested
```

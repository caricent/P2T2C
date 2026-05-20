# P2T2C Release Selector

P2T2C means **Proposal-to-Truth-to-Code**.

## Overview

P2T2C is a workflow template for developers, product-minded engineers, technical leads, and AI-assisted software teams that want AI to help move implementation forward without quietly changing product rules, architecture decisions, or acceptance criteria.

Modern AI coding workflows often fail at the handoff between intent and implementation: a proposal becomes a plan, the plan becomes code, and the code later drifts away from the original business Truth. P2T2C makes that chain explicit. It separates proposals, authoritative Truth, execution documents, coding tasks, acceptance, and closure so every change has a traceable source and every drift has a defined human decision point.

The goal is to let AI stay productive while keeping humans in control of rule changes. Clear, non-conflicting proposals can move quickly through Change Pack, Gate A, Truth Patch, Execution Pack, task execution, and Closure Report. Ambiguous proposals, Truth conflicts, ADR needs, failed checks, or Truth Drift stop at explicit gates instead of being silently resolved by the AI.

Use P2T2C when you need:

- A repeatable AI collaboration workflow for real software projects.
- A source-of-truth structure that separates current rules from plans, prompts, tests, and implementation details.
- Human approval before business Truth, governance, or architectural decisions change.
- Install and upgrade scripts that can be copied into existing projects without overwriting project-owned files.
- Bilingual release roots for English and Chinese teams that need the same workflow in language-specific documentation.

## Workflow Diagram

```mermaid
flowchart TD
  proposal["Human proposal"] --> change_pack["AI generates Change Pack"]
  truth["Current Truth in docs/sot and ADRs"] --> change_pack

  change_pack --> admission{"Admission decision"}
  admission -->|Ready| gate_a{"Gate A: approve Truth change?"}
  admission -->|Blocked| blocking["Blocking Brief: repair proposal, resolve conflict, or create ADR"]
  blocking --> proposal

  gate_a -->|Approved| truth_patch["Apply Truth Patch"]
  gate_a -->|Not approved| proposal
  truth_patch --> execution_pack["Generate Execution Pack: spec, plan, tasks"]
  execution_pack --> coding["Execute one coding task"]
  coding --> task_check{"More tasks?"}
  task_check -->|Yes| coding
  task_check -->|No| acceptance["Acceptance: build, test, lint, governance check"]

  acceptance --> acceptance_result{"Checks pass?"}
  acceptance_result -->|No| fix_code["Fix implementation or docs, then rerun acceptance"]
  fix_code --> acceptance
  acceptance_result -->|Yes| closure["Closure Report"]

  closure --> drift{"Truth Drift found?"}
  drift -->|No| close["Close"]
  drift -->|Execution docs only| backfill["Backfill spec, plan, or tasks"]
  drift -->|Truth drift| gate_b{"Gate B: human Truth decision"}

  gate_b -->|Fix code| fix_code
  gate_b -->|Accept code| truth_patch
  gate_b -->|Need CP or ADR| proposal
```

This repository publishes the P2T2C workflow template as a bilingual MIT-licensed release selector. The repository root is only a selector and aggregate check surface; it is not a P2T2C release root.

## Release Roots

- `P2T2C_EN/`: English release root
- `P2T2C_CN/`: Chinese release root

Choose one release root before installing or upgrading:

```bash
cd P2T2C_EN
make check
make p2t2c-install-dry-run TARGET=/path/to/project
```

```bash
cd P2T2C_CN
make check
make p2t2c-install-dry-run TARGET=/path/to/project
```

## Repository Checks

Run both release checks and verify release-root checksums:

```bash
make check
make checksums
```

Run install and upgrade smoke tests for both release roots:

```bash
bash scripts/release_smoke_test.sh
```

GitHub Actions runs the same release checks and smoke tests through `.github/workflows/ci.yml`.

## License

P2T2C is released under the MIT License. See `LICENSE`.

Each standalone release root also includes `.p2t2c/P2T2C_LICENSE.md` so the license notice is preserved when installing only `P2T2C_EN/` or `P2T2C_CN/` into another project.

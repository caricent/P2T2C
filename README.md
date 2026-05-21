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

The workflow runs through six stages. The diagram groups every step into the stage it
belongs to and color-codes the role that owns it: orange = human action, gold = human
decision gate, blue = AI action, purple = automatic decision, red = blocked / repair,
green = done.

```mermaid
flowchart TD
  classDef human fill:#ffe8cc,stroke:#e8590c,stroke-width:2px,color:#1a1a1a;
  classDef ai fill:#e7f5ff,stroke:#1971c2,stroke-width:1.5px,color:#1a1a1a;
  classDef gate fill:#fff3bf,stroke:#f08c00,stroke-width:2.5px,color:#1a1a1a;
  classDef decision fill:#f3f0ff,stroke:#7048e8,stroke-width:1.5px,color:#1a1a1a;
  classDef stop fill:#ffe3e3,stroke:#e03131,stroke-width:2px,color:#1a1a1a;
  classDef done fill:#ebfbee,stroke:#2f9e44,stroke-width:2px,color:#1a1a1a;

  subgraph S1["Stage 1 · Propose"]
    proposal["Human proposal"]:::human
    truth[("Current Truth<br/>docs/sot + ADRs")]:::ai
    change_pack["AI: generate Change Pack"]:::ai
  end

  subgraph S2["Stage 2 · Admit &amp; Gate A"]
    admission{"Admission?"}:::decision
    blocking["Blocking Brief<br/>repair · resolve conflict · ADR"]:::stop
    gate_a{"Gate A — human<br/>approve Truth change?"}:::gate
  end

  subgraph S3["Stage 3 · Patch &amp; Plan"]
    truth_patch["Apply Truth Patch"]:::ai
    execution_pack["AI: Execution Pack<br/>spec · plan · tasks"]:::ai
  end

  subgraph S4["Stage 4 · Build"]
    coding["Execute one coding task"]:::ai
    task_check{"More tasks?"}:::decision
  end

  subgraph S5["Stage 5 · Accept"]
    acceptance["Acceptance<br/>build · test · lint · governance"]:::ai
    acceptance_result{"Checks pass?"}:::decision
    fix_code["Fix implementation or docs"]:::ai
  end

  subgraph S6["Stage 6 · Close"]
    closure["Closure Report"]:::ai
    drift{"Truth Drift?"}:::decision
    gate_b{"Gate B — human<br/>Truth decision"}:::gate
    backfill["Backfill spec · plan · tasks"]:::ai
    close(["Close"]):::done
  end

  proposal --> change_pack
  truth --> change_pack
  change_pack --> admission
  admission -->|Ready| gate_a
  admission -->|Blocked| blocking
  blocking -.->|repair| proposal
  gate_a -->|Approved| truth_patch
  gate_a -->|Not approved| proposal
  truth_patch --> execution_pack
  execution_pack --> coding
  coding --> task_check
  task_check -->|Yes, next task| coding
  task_check -->|No| acceptance
  acceptance --> acceptance_result
  acceptance_result -->|No| fix_code
  fix_code -.->|rerun| acceptance
  acceptance_result -->|Yes| closure
  closure --> drift
  drift -->|No drift| close
  drift -->|Execution docs only| backfill
  backfill --> close
  drift -->|Truth drift| gate_b
  gate_b -->|Fix code| fix_code
  gate_b -->|Accept code| truth_patch
  gate_b -->|Need SP or ADR| proposal
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

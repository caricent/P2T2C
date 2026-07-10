# ADR-013: Native Truth-governed Execution Method Layer

Status: Accepted
Date: 2026-07-10

## Context

P2T2C already governs risk routing, Truth, human gates, verification, and closure. It needed reusable execution discipline for design refinement, test-first work, debugging, review, and safe workspace boundaries without creating a competing source of business rules or an external plugin dependency.

## Decision

P2T2C ships five native bilingual methods under `.p2t2c/skills/`. P2T2C remains the control layer; methods are subordinate to Truth, source priority, R0/R1/R2 routing, and Gate A/B. New installations default to the balanced required profile. Existing projects remain advisory until they opt in through project configuration.

## Consequences

- New R1/R2 templates record method checkpoints and method-enabled CRs preserve evidence.
- Required-mode governance checks enforce evidence only for declared method-enabled artifacts.
- Upstream Superpowers remains attribution-only; it is not bundled or required at runtime.
- This introduces managed workflow assets and an upgrade migration, but no migration of project-owned historical artifacts.

# ADR

ADRs record why important decisions were made. An ADR is no longer a fixed artifact for every R2.

## When an ADR Is Needed

- Change architecture principles.
- Change the source of truth for data.
- Change API / protocol boundaries.
- Change permission / security / privacy boundaries.
- Change AI responsibilities.
- Change sync strategy.
- Change the core workflow.

## Important Rule

ADR explains why. SoT defines what currently happens.

If an ADR is accepted, executable rules must be projected into `docs/sot/`.

R1 cannot change Truth through an ADR. CPK, work, machine evidence, and CR cannot replace SoT. When the current instruction already decides complete R2 semantics, record `gate_a: satisfied` without duplicate approval.

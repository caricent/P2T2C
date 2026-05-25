# Submit Proposals

This directory is the Proposal entrypoint for P2T2C.

## When to Create a SP

- Add a feature.
- Adjust requirements.
- Modify business rules.
- Modify architecture / data / AI / permissions / sync / testing criteria.

## Naming

```text
SP-YYYYMMDD-short-title.md
```

## Workflow

1. Copy `SP_TEMPLATE.md` to `SP-YYYYMMDD-short-title.md`, or ask AI to create that SP file from the template.
2. Write final requirements and non-goals clearly.
3. Ask AI to generate a Change Pack and start with Admission Summary.
4. If the SP does not require SoT or ADR changes, AI uses Fast Path and generates the CPK directly.
5. If the SP requires SoT or ADR changes, AI must enter Gate A, present explicit decision options, and wait for the human choice before modifying Truth or ADRs.
6. If the Change Pack uses Blocked Path, repair the Proposal, resolve the conflict, or handle the ADR first.

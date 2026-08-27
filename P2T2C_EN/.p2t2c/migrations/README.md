# P2T2C Template Migrations

Latest migration: `0.14.0-to-0.14.1.md`, reducing context and duplicate execution while retaining the adaptive-v2 contract.

This directory records P2T2C workflow template migrations.

Migration files explain how an older project can safely adopt a newer P2T2C release without modifying project-owned business files.

Naming:

```text
{from-version}-to-{to-version}.md
```

Rules:

- Migration notes describe workflow/template/governance changes only.
- Business Truth, ADR, specs, code, tests, and historical Closure Reports are not migrated automatically.
- New workflow rules apply to work created after the upgrade; historical v2 artifacts remain valid.

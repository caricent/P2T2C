# P2T2C Template Migrations

This directory records P2T2C workflow template migrations.

Migration files explain how an older project can safely adopt a newer P2T2C release without modifying project-owned business files.

Naming:

```text
{from-version}-to-{to-version}.md
```

Rules:

- Migration notes describe workflow/template/governance changes only.
- Business Truth, ADR, specs, code, tests, and historical Closure Reports are not migrated automatically.
- New workflow rules apply to CPs created after the upgrade.

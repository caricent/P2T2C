# Rule Block Template

Important current Truth rules use stable Rule IDs. Historical and supersession context belongs in migrations, Governance History, or Git history, outside the current execution Rule Block.

```text
## RULE-{AREA}-{NNN}: {Rule Name}

Status: Active

Rule:

{A clear, executable, verifiable current rule.}

Validation:

- {Automated check or manual acceptance}

Stop the line if:

- {Condition that requires human confirmation}
```

Constraints:

- Rule IDs must be unique in current non-History SoT documents.
- Code does not require `Implements: RULE-*` comments.
- EARS statements and task acceptance steps do not require per-line Rule ID tags.

# Execution Documents

R1/R2 store a compact execution trio here:

```text
specs/{NNN-feature}/
  spec.md
  plan.md
  tasks.md
```

- `spec.md` must reference its `docs/change_packs/CPK-*.md` in front matter.
- `plan.md` records implementation strategy, impact, and risk.
- `tasks.md` records multiple related tasks in one work batch and batch-level acceptance.
- R0 creates no execution docs.
- Per-task Actual results, `Acceptance scope`, and per-line Rule ID tags are not required.

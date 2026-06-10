# Change Packs

`docs/change_packs/` stores persistent Change Packs for `R1` and `R2` work.

- R0 does not create a CPK.
- R1 creates a compact CPK and must not change Truth.
- R2 creates a complete CPK; only undecided semantics require Gate A.

Naming:

```text
CPK-YYYYMMDD-short-title.md
```

Use `CPK_TEMPLATE.md` in this directory when creating a CPK.

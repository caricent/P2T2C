# Contributing

P2T2C is published as a bilingual release selector with two independently checkable release roots:

- `P2T2C_EN/`
- `P2T2C_CN/`

Keep both release roots aligned unless the change is intentionally language-specific.

## Local Checks

Run the full release checks before opening a pull request:

```bash
make check
make checksums
bash scripts/release_smoke_test.sh
```

## Change Guidelines

- Keep workflow Truth in each release root under `docs/sot/**`.
- Do not make prompts, specs, tests, or code comments the only source of workflow rules.
- Update checksums and `.p2t2c/lock.sha256` whenever managed release-root files change.
- Preserve English-only managed workflow docs in `P2T2C_EN/`.
- Preserve Chinese-only managed workflow docs in `P2T2C_CN/`, except stable workflow tokens, paths, commands, status values, CLI flags, shell output, and legal license text.

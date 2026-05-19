# P2T2C Release Selector

P2T2C means **Proposal-to-Truth-to-Code**.

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

Each standalone release root also includes `P2T2C_LICENSE.md` so the license notice is preserved when copying only `P2T2C_EN/` or `P2T2C_CN/` into another project.

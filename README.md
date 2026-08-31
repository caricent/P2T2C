# P2T2C Release Selector

P2T2C means **Proposal-to-Truth-to-Code**. Version 0.15 uses an action-oriented core workflow:

```text
Explore optional -> Propose -> Apply -> Verify optional -> Archive
```

## Active Documents

- `docs/proposals/SP-*.md`: why, what, observable outcomes, and the human decision.
- `docs/specs/<change>/design.md`: implementation approach.
- `docs/specs/<change>/tasks.md`: implementation checklist and completion summary.
- `docs/sot/**`: the only current behavioral authority.

Historical ADRs, CPKs, CR/evidence, and legacy specs move only through explicit `docs-migrate` into non-authoritative `docs/reference/archive/**`.

P2T2C does not orchestrate project tests, CI, or code review. Archive checks known blockers and marks tasks completed in place; it runs no tests or release smoke.

## Release Roots

- `P2T2C_EN/`: English release root
- `P2T2C_CN/`: Chinese release root

The repository root is only a selector and aggregate release-check surface. Current Truth lives inside each release root under `docs/sot/**`.

## Release Checks

```bash
make check
make checksums
bash scripts/release_smoke_test.sh
```

These commands certify P2T2C itself and are not part of ordinary project Apply or Archive.

## Install

Choose one release root:

```bash
cd P2T2C_EN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

or:

```bash
cd P2T2C_CN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

## Attribution and License

The core action model and design/tasks split draw from Fission-AI/OpenSpec. P2T2C and OpenSpec are MIT-licensed; release roots include attribution details under `docs/reference/`.

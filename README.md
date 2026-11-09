# P2T2C Release Selector

P2T2C means **Proposal-to-Truth-to-Code**. This branch prepares **0.16.0-rc.1**. The model chooses how to retrieve context, implement, diagnose, and check; goals, Truth, necessary decisions, actual acceptance, and safe document completion remain explicit.

For eligible simple R1, the model prefers compact v2 with one SP when consumer support exists. Complex R1, every R2, and unsupported integrations retain standard v1 with SP, design.md, and tasks.md. Existing work is not converted; create without an explicit shape retains standard compatibility.

This work delivers P2T2C templates and validates their tools in isolated projects; it does not modify consumer repositories. Compact remains a candidate capability. Long-term efficiency and cross-device studies are optional, not prerequisites for simpler methods. Normal closure archives once without stacked diagnostic commands or rerunning project tests and review. See the selected release root for authoritative rules, commands, and compatibility details.

## Release Roots

- `P2T2C_EN/`: English release root
- `P2T2C_CN/`: Chinese release root

The repository root is only a selector and aggregate release-check surface. Current Truth lives inside each release root under `docs/sot/**`.

Release templates keep `docs/proposals/` and `docs/specs/` empty except for their README files. Reusable templates live in `.p2t2c/templates/core/`; actual SP, design, and tasks records are created only when a project starts work. Framework maintenance records are kept outside the template repository.

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

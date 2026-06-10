# Template Upgrade Pack - P2T2C {from-version} -> {to-version}

Status: Draft | Applied | Blocked
Source release: `{path or URL}`

## Upgrade Summary

{Workflow, template, or governance capability changes in this upgrade.}

## Compatibility

| Item | Decision |
|---|---|
| New work after upgrade | Use the upgraded risk-routed workflow |
| Historical SPs, CPKs, specs, tasks, and CRs | Leave unchanged |
| Project-owned Truth and ADRs | Do not modify |

## Managed File Actions

| File | Action |
|---|---|
| `{path}` | Update / Create / Remove when lock matches |

## Manual Review

| File | Reason |
|---|---|
| `{path}` | Local modification / conflict |

## Project-owned Files Untouched

Upgrade must not modify project business Truth, ADR instances, SP instances, CPK instances, specs, code, tests, database files, or historical CRs.

## Validation

```bash
bash .p2t2c/bin/check_p2t2c.sh
shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
```

## Closure

Decision: CLOSE | MANUAL_CONFLICT_RESOLUTION_REQUIRED

```bash
bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/{upgrade-id}
```

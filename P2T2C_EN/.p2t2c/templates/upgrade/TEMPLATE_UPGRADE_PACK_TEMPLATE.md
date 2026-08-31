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
| Receipt v1/v2 and historical evidence sidecars | Leave unchanged; only legacy work continues to use them |
| Active `.p2t2c/runs/**` and cache state | Never release-managed or rollback targets |
| Managed file modes | Reconcile to policy; rollback restores prior modes |
| Project-owned Truth and ADRs | Do not modify |
| Document layout | Normal upgrade does not move it; only explicit `docs-migrate` changes it |

## Managed File Actions

| File | Action |
|---|---|
| `{path}` | Update / Create / Remove when lock matches |

## Manual Review

| File | Reason |
|---|---|
| `{path}` | Local modification / conflict |

## Project-owned Files Untouched

Upgrade must not modify project business Truth, ADR instances, SP instances, CPK instances, specs, code, tests, database files, historical CRs, evidence sidecars, active runs, cache state, or `.p2t2c/project_config.yaml`.

## Validation

```bash
bash .p2t2c/bin/check_p2t2c.sh
./.p2t2c/bin/p2t2c --help
shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
```

## Closure

Decision: CLOSE | MANUAL_CONFLICT_RESOLUTION_REQUIRED

```bash
bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/{upgrade-id}
```

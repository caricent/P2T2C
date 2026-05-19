# Template Upgrade Pack — P2T2C {from-version} -> {to-version}

Status: Draft | Applied | Blocked
Generated at: {YYYY-MM-DD}
Source release: `{path or URL}`

---

## 1. Upgrade Summary

{What P2T2C workflow / template / governance capability changes in this upgrade.}

---

## 2. Compatibility

| Item | Decision |
|---|---|
| New CPs after upgrade | Use upgraded P2T2C workflow |
| Existing specs / tasks | Leave unchanged |
| Historical Closure Reports | Leave unchanged |
| Project-owned Truth / ADR | Do not modify |

|---|---|

---

## 3. Files to Update

| File | Ownership | Action |
|---|---|---|
| `{path}` | core-managed / governance-managed | Update / Create |

---

## 4. Files to Review Manually

| File | Reason |
|---|---|
| `{path}` | Local modification / conflict |

---

## 5. Project Truth Untouched

The upgrade MUST NOT modify:

- `docs/sot/product/**`
- `docs/sot/data/**`
- `docs/sot/api/**`
- `docs/sot/client/**`
- `docs/sot/server/**`
- `docs/sot/ai/**`
- `docs/sot/testing/**`
- `docs/adr/**`
- `specs/**`
- `src/**`
- `tests/**`

---

## 6. Validation Commands

```bash
make check
```

Optional for template source packages:

```bash
shasum -a 256 -c CHECKSUMS.sha256
```

---

## 7. Upgrade Closure

Decision: CLOSE | MANUAL_CONFLICT_RESOLUTION_REQUIRED

Rollback command:

```bash
make p2t2c-rollback UPGRADE=.p2t2c/upgrade/{upgrade-id}
```

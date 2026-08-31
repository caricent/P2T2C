# Change Packs

`docs/change_packs/` stores persistent Change Packs for `R1` and `R2`. New work uses `schema_version: 3` and `methodology_profile: p2t2c-adaptive-v2`; v0.14 trials it in advisory mode and does not claim required before real A/B plus promotion decision.

- R0 creates no CPK by default.
- Bounded R1 creates one CPK v3 containing intent, Truth references, acceptance, strategy, and closure evidence.
- Architectural R1 creates CPK v3 and references one `specs/{feature}/work.md` through `work_pack`.
- R2 creates a complete CPK v3 and Truth Patch; only undecided semantics require Gate A, and closure automatically creates the matching CR.
- A spike ships no retained change; upgrade execution shape and reroute before delivery.

CPK also declares Truth ref+SHA-256 digest, unique ownership batch IDs, and legacy startup. Bounded/spike uses ownership none and legacy false; architectural lists IDs and uses legacy true only for real old-workflow startup. Spike cannot close.

At R1 closure, tooling projects evidence bound to final tree and `contract_digest` into CPK markers. R2 projects into automatic CR. Reviewers differ from implementer and required reviews have zero findings; receipt `local_consistency` is not adversarial proof.

A v0.14.1 CPK marker retains receipt v2 only, while a content-addressed sidecar preserves raw events. Recover with `p2t2c status` and `p2t2c evidence summary` instead of reading the complete marker/sidecar by default.

Naming:

```text
CPK-YYYYMMDD-short-title.md
```

Use `CPK_TEMPLATE.md` for new CPKs. Historical schema v2 CPKs are not migrated or rewritten.

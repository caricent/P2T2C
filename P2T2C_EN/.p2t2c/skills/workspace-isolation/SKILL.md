---
name: p2t2c-workspace-isolation
description: Establish risk-proportional isolation, ownership, and recovery boundaries for P2T2C writes and multi-Agent integration.
---

# Workspace Isolation

Detect and prefer host-managed isolation. With `isolation: auto`, create/request a worktree only for R2, parallel writes, or explicit isolation; otherwise record current branch, base SHA, and applicable baseline in an `isolation` event carrying contract digest.

- Read-only exploration may fully parallelize.
- Architectural parallel writes use unique CPK batch IDs with disjoint files, explicit baseline, one integration controller, and one batch review per ID.
- Batch homogeneous microtasks sharing acceptance; assign tightly coupled files to one ownership batch.
- Only the controller spawns Agents; implementers/reviewers cannot recursively fan out.
- Handoff uses CPK/work pointers, extracted brief, base/head diff, and ledger path instead of copied chat.
- Before removing a worktree, inspect untracked/uncommitted content. Stop and list paths instead of force deletion.

Isolation protects implementation state but cannot replace Gate A/B, Truth, dangerous-operation authority, independent review, or final-tree full verification.

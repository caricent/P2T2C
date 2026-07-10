---
name: p2t2c-workspace-isolation
description: Select a safe, proportionate workspace boundary for P2T2C execution.
---

# Workspace Isolation

Detect whether the host already provides an isolated workspace. Prefer that mechanism. With `isolation: auto`, create or request an isolated worktree only for R2 work, parallel execution, or an explicit user request; otherwise record the current branch and clean baseline.

Before execution, inspect the working tree and run the applicable baseline verification. Do not overwrite unrelated local changes. Parallel work is allowed only for independently bounded R2 tasks with non-overlapping ownership; each result still receives the required review and batch verification.

Workspace isolation protects implementation state only. It never replaces Gate A, Gate B, Truth review, or confirmation for dangerous operations.

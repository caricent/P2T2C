# P2T2C Install Report — {install-id}

Status: DRY_RUN | APPLIED | ALREADY_INSTALLED | BLOCKED
Source: `{source-path}`
Target: `{target-path}`
Generated at: {YYYY-MM-DD HH:MM:SS}

---

## 1. Installed

- {files copied into target}

---

## 2. Unchanged

- {files already identical}

## 2a. Mode Repairs

- {identical-byte managed files reconciled to deterministic mode policy}

---

## 3. Conflicts

Existing files were not overwritten:

- {conflict files}

Suggested manual integration:

- If an AI tool only auto-loads root-level `AGENTS.md`, reference `P2T2C_AGENTS.md` from the project-owned `AGENTS.md`.
- Add P2T2C targets to the project-owned `Makefile` if needed.
- Keep the existing project README and link to `P2T2C_README.md` if needed.

---

## 4. Skipped Denied Paths

- {paths protected by install denylist}

---

## 5. Validation

- {validation result}

## 6. 0.15.0 Runtime Boundary

- Installed workflow assets include core SP/design/tasks templates, Documents Archive, explicit docs-migrate, and the 0.14.x context/evidence/verify/close compatibility engine.
- Install created no active SP/specs, run, cache, cold-archive instance, or evidence. Fresh config explicitly selects core-v1 while legacy defaults remain adaptive-v2.

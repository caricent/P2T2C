# Changelog

All notable changes to P2T2C are documented here.

## 0.8.0 - 2026-05-21

- Added `RULE-GOV-009` rule identifier integrity: `make check` now scans `docs/sot/**` for duplicate RULE-IDs, dangling lifecycle references, broken bidirectional supersede links, and superseded-yet-Active rules.
- Added `RULE-GOV-010` code-to-Truth back-reference anchors: implementing code carries a pointer-only `Implements: RULE-...` comment; the scan is soft and runs only when a `src/` tree exists.
- Added `RULE-GOV-011` EARS acceptance binding: each EARS acceptance statement and task acceptance step names the rule identifier it verifies.
- Updated truth, spec, and tasks templates and the execution-pack prompt to project the new rules.

## 0.7.0 - 2026-05-20

- Renamed installed P2T2C entry files to `P2T2C_README.md` and `P2T2C_AGENTS.md`.
- Moved release metadata files under `.p2t2c/` to avoid project-root filename conflicts.
- Stopped installing a root-level Makefile; project checks run through `.p2t2c/bin/check_p2t2c.sh`.

## 0.6.0 - 2026-05-20

- Moved internal prompts, templates, scripts, and migration notes under `.p2t2c/`.
- Kept installed project-root P2T2C work surfaces focused on `docs/` and `specs/`.
- Added safe upgrade handling for removing unchanged legacy root-level internal assets.

## 0.5.0 - 2026-05-19

- Prepared the bilingual P2T2C release selector for public MIT publication.
- Published independent English and Chinese release roots with checksums, upgrade metadata, install scripts, and governance checks.
- Added safe install and upgrade flows with dry-run, conflict detection, lock files, and rollback support.

# P2T2C Workflow Template

P2T2C means **Proposal-to-Truth-to-Code**.

P2T2C helps developers collaborate with AI without letting requirements, authoritative Truth, implementation plans, code changes, and acceptance results drift apart. It keeps AI productive while preventing it from changing business rules without confirmation or Truth support.

```text
Proposal -> Change Pack -> Gate A -> Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

Default behavior: AI keeps moving. It pauses only for explicit gates, conflicts, missing Truth, failed acceptance, or Truth Drift.

Language policy: this release root is English-only for managed workflow documents. Use `../P2T2C_CN/` for the Chinese release. Stable workflow tokens, paths, commands, status values, CLI flags, and shell runtime output remain English.

For AI agents, the only operational entry is:

```text
AGENTS.md
```

---

## 1. First Setup

Copy the template into a project:

```bash
cp -R P2T2C_EN/. your-project/
cd your-project
cp project_config.example.yaml project_config.yaml
```

Edit `project_config.yaml` and fill in the project name, description, language, and technology stack.

Then run:

```bash
make check
```

Expected result:

```text
P2T2C checks passed.
```

---

## 2. Human workflow

1. Write a Change Proposal in `docs/change_proposals/`.
2. Ask AI to generate a Change Pack from the CP.
3. Review Gate A: approve and apply the Truth Patch, or revise, reject, split, or resolve the proposal.
4. Let AI generate `spec.md`, `plan.md`, and `tasks.md`.
5. Let AI execute one task at a time.
6. Review the Closure Report only if it reports Truth Drift.

Gate B is only needed when Closure Decision is:

```text
HUMAN_TRUTH_DECISION_REQUIRED
```

---

## 3. Install into Another Project

Use this only for a project that has never used P2T2C.

Dry-run first:

```bash
make p2t2c-install-dry-run TARGET=/path/to/project
```

After reviewing the output:

```bash
make p2t2c-install TARGET=/path/to/project
```

Install copies missing workflow harness files only. It does not overwrite existing files, rewrite business documents, infer Truth, or edit source code.

---

## 4. Upgrade an Existing P2T2C Project

Run upgrade commands from the target project root, but invoke the upgrade script from this release root.

Dry-run first:

```bash
cd /path/to/project
/path/to/P2T2C_EN/scripts/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_EN
```

After reviewing the output:

```bash
/path/to/P2T2C_EN/scripts/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_EN
```

Rollback an applied upgrade:

```bash
make p2t2c-rollback UPGRADE=.p2t2c/upgrade/{upgrade-id}
```

Projects already on the current harness may also use the local Makefile aliases.

Upgrade scripts may update workflow, template, prompt, governance, and metadata files when unchanged since the last lock. They must not modify project-owned Truth, ADRs, specs, source code, tests, database files, or historical Closure Reports.

---

## 5. Directory Map

| Path | Responsibility |
|---|---|
| `README.md` | Human entry |
| `AGENTS.md` | AI operational entry |
| `P2T2C_LICENSE.md` | MIT license notice for standalone release-root copies |
| `project_config.example.yaml` | Project config template |
| `CHECKSUMS.sha256` | Release file checksums |
| `.p2t2c/` | Template metadata, ownership, and lock state |
| `scripts/` | Check, install, upgrade, rollback |
| `docs/change_proposals/` | Proposal templates and CPs |
| `docs/adr/` | Accepted architectural or policy decision records |
| `docs/sot/` | Current project Truth |
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | Canonical P2T2C governance Truth |
| `docs/closure/` | Closure Reports |
| `docs/reference/` | Historical reference only; not read by default |
| `sdd/templates/` | Spec / Plan / Tasks templates |
| `specs/` | Feature execution documents |
| `templates/` | Reusable P2T2C artifact templates |
| `prompts/` | Stage prompts for AI agents |
| `migrations/p2t2c/` | Template migration notes |

Business rules belong in `docs/sot/`. ADRs explain why decisions were made. Specs, plans, tasks, prompts, tests, and code must not become the only source of a business rule.

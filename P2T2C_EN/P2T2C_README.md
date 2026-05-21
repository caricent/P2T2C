# P2T2C Workflow Template

P2T2C means **Proposal-to-Truth-to-Code**.

Abbreviations: SP = Submit Proposal (the human-authored proposal, filename `SP-YYYYMMDD-...`); CPK = Change Pack (the AI-generated candidate pack). They no longer share the CP abbreviation.

P2T2C helps developers collaborate with AI without letting requirements, authoritative Truth, implementation plans, code changes, and acceptance results drift apart. It keeps AI productive while preventing it from changing business rules without confirmation or Truth support.

```text
Proposal -> Change Pack -> Gate A -> Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

Default behavior: AI keeps moving. It pauses only for explicit gates, conflicts, missing Truth, failed acceptance, or Truth Drift.

Language policy: this release root is English-only for managed workflow documents. Use `../P2T2C_CN/` for the Chinese release. Stable workflow tokens, paths, commands, status values, CLI flags, and shell runtime output remain English.

For AI agents, the only operational entry is:

```text
P2T2C_AGENTS.md
```

---

## 1. First Setup

Install from the English P2T2C release root into a target project:

```bash
cd /path/to/P2T2C_EN
make p2t2c-install-dry-run TARGET=/path/to/project
make p2t2c-install TARGET=/path/to/project
```

Then enter the target project and create the project config:

```bash
cd /path/to/project
cp .p2t2c/templates/project_config.example.yaml .p2t2c/project_config.yaml
```

Edit `.p2t2c/project_config.yaml` and fill in the project name, description, language, and technology stack.

Then run:

```bash
bash .p2t2c/bin/check_p2t2c.sh
```

Expected result:

```text
P2T2C checks passed.
```

---

## 2. Human workflow

1. Write a Submit Proposal in `docs/submit_proposals/`.
2. Ask AI to generate a Change Pack from the SP.
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
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --dry-run --source /path/to/P2T2C_EN
```

After reviewing the output:

```bash
/path/to/P2T2C_EN/.p2t2c/bin/p2t2c_upgrade.sh --apply --source /path/to/P2T2C_EN
```

Rollback an applied upgrade:

```bash
make p2t2c-rollback UPGRADE=.p2t2c/upgrade/{upgrade-id}
```

Projects that maintain their own Makefile aliases may continue using those aliases; new installs do not create a root-level Makefile.

Upgrade scripts may update workflow, template, prompt, governance, and metadata files when unchanged since the last lock. They must not modify project-owned Truth, ADRs, specs, source code, tests, database files, or historical Closure Reports.

---

## 5. Directory Map

After installation, P2T2C keeps `P2T2C_README.md` and `P2T2C_AGENTS.md` at the project root as entry files, and exposes only `docs/` and `specs/` as daily work surfaces. Prompts, templates, scripts, checksums, license, and migration notes live under hidden `.p2t2c/`.

| Path | Responsibility |
|---|---|
| `P2T2C_README.md` | Human entry |
| `P2T2C_AGENTS.md` | AI operational entry |
| `.p2t2c/P2T2C_LICENSE.md` | MIT license notice for standalone release-root copies |
| `.p2t2c/templates/project_config.example.yaml` | Project config template |
| `.p2t2c/CHECKSUMS.sha256` | Release file checksums |
| `.p2t2c/` | Template metadata, ownership, and lock state |
| `.p2t2c/bin/` | Check, install, upgrade, rollback |
| `docs/submit_proposals/` | Proposal templates and SPs |
| `docs/adr/` | Accepted architectural or policy decision records |
| `docs/sot/` | Current project Truth |
| `docs/sot/governance/P2T2C_GOVERNANCE.md` | Canonical P2T2C governance Truth |
| `docs/closure/` | Closure Reports |
| `docs/reference/` | Historical reference only; not read by default |
| `.p2t2c/templates/execution/` | Spec / Plan / Tasks templates |
| `specs/` | Feature execution documents |
| `.p2t2c/templates/` | Reusable P2T2C artifact templates |
| `.p2t2c/prompts/` | Stage prompts for AI agents |
| `.p2t2c/migrations/` | Template migration notes |

Business rules belong in `docs/sot/`. ADRs explain why decisions were made. Specs, plans, tasks, prompts, tests, and code must not become the only source of a business rule.

# P2T2C_GOVERNANCE — Canonical Workflow Truth

Status: Active
Owner: Project maintainers
Last updated: 2026-05-20

## AI Reading Contract

- Canonical scope: P2T2C workflow governance, Truth document style, language policy, execution-pack rules, gates, and drift handling.
- Must-read with: `P2T2C_AGENTS.md` and `docs/sot/manifest.yaml`.
- Do not infer: AI must not invent business rules, silently accept conflicts, or treat execution docs as Truth.
- Stop-the-line if: any rule below conflicts with an accepted CP / ADR or current SoT.

---

## 1. Workflow

### RULE-GOV-001: Single Exception-Gated Path

Status: Active
Applies to: P2T2C workflow
Source: Template maintainers
Supersedes: previous unnumbered workflow section
Superseded by: None
Migration required: Yes, template metadata moves to `0.4.0`

Rule:

P2T2C uses one path:

```text
Proposal -> Change Pack -> Gate A -> Truth Patch + Execution Pack -> Coding -> Acceptance -> Closure Report
```

Default behavior is to proceed. AI pauses only for gates, conflicts, missing Truth, failed checks, or Truth Drift.

Validation:

- `make check`
- Change Pack Admission Summary must decide Fast Path vs Blocked Path.

Stop-the-line if:

- Any implementation requires a new workflow path not defined here.

### Stages

| Stage | Output | Rule|
|---|---|---|
| Proposal| CP | Human owns final intent.|
| Change Pack| Admission Summary, Impact Review, Fast Path or Blocked Path | AI analyzes; no file changes.|
| Gate A | Apply, revise, stop, split, or reject | Human decides.|
| Truth Patch | SoT / ADR / manifest updates | Only after Gate A.|
| Execution Pack| `spec.md`, `plan.md`, `tasks.md` | Projects accepted Truth into executable work.|
| Coding| Code and task Actual results | AI executes one task at a time.|
| Acceptance| Build, test, lint, governance checks | Failures stop the line.|
| Closure Report| Close, backfill docs, or require Truth decision | Truth Drift triggers Gate B.|

---

## 2. Document Roles

### RULE-GOV-002: Truth Boundaries

Status: Active
Applies to: P2T2C documents
Source: Template maintainers
Supersedes: previous unnumbered document-role table
Superseded by: None
Migration required: Yes, templates become bilingual in-place

Rule:

Business rules belong in `docs/sot/**`. ADRs explain why. Specs, plans, tasks, prompts, tests, code comments, and chat history must not be the only source of a business rule.

| Document | Responsibility | Truth? | May define business rules? |
|---|---|---|---|
| Change Proposal| Proposed change| No | Proposal only|
| ADR | Decision background, tradeoffs, consequences| Decision history| Only records confirmed decisions|
| SoT | Current authoritative project rules| Yes | Yes |
| Spec | What a feature does| No | No, must cite Truth|
| Plan | How to implement| No | No |
| Tasks | Independently verifiable work| No | No |
| Closure Report | Acceptance and drift decision| No | No; Truth Drift requires human decision|

Validation:

- Specs, plans, and tasks cite Truth references instead of defining standalone rules.

Stop-the-line if:

- A lower-priority document conflicts with current SoT or accepted ADR.

---

## 3. Admission and Gates

### RULE-GOV-003: Admission and Human Gates

Status: Active
Applies to: Change Pack generation and application
Source: Template maintainers
Supersedes: previous unnumbered admission/gate section
Superseded by: None
Migration required: Yes, Change Pack template becomes bilingual in-place

Rule:

Change Pack must start with Admission Summary. Admission decision must be one of:

- `READY`
- `NEEDS_PROPOSAL_REPAIR`
- `CONFLICTS_WITH_TRUTH`
- `CONFLICTS_WITH_IMPLEMENTED_TRUTH`
- `ADR_REQUIRED`
- `OUT_OF_SCOPE`

`READY` uses Fast Path and may include a Truth Patch Candidate and Execution Pack Summary.

Any non-`READY` decision uses Blocked Path and must include:

```text
Truth Patch Candidate: Not generated
```

Gate A is required before applying a Truth Patch. Gate B is required only when Closure Decision is:

```text
HUMAN_TRUTH_DECISION_REQUIRED
```

Validation:

- Blocked Path provides a single Blocking Brief with human decision options.
- AI does not decide conflicts, accept ADRs, or silently retire old Truth.

Stop-the-line if:

- Gate A approval is missing before Truth changes.
- Gate B is needed and no human decision exists.

---

## 4. Stop-the-line Conditions

AI must stop when:

- CP information is insufficient to safely generate a Truth Patch.
- CP conflicts with current SoT / ADR.
- CP conflicts with Active and implemented Truth, and no human resolution exists.
- A new or modified ADR is required.
- Continuing requires a business rule not defined by Proposal, accepted CP, ADR, or SoT.
- Implementation requires a new table, field, interface, page, state, permission, AI responsibility, sync object, or workflow not defined by Truth.
- Coding invalidates a key Plan assumption.
- Build, test, lint, or governance check fails.
- Code-to-Truth Drift is substantive Truth Drift.

If any Stop-the-line Checklist item is Yes, Admission decision must not be `READY`.

---

## 5. Truth Document Style and Language Policy

### RULE-GOV-004: Rule Block Style

Status: Active
Applies to: `docs/sot/**`
Source: Template maintainers
Supersedes: previous unnumbered Truth document style section
Superseded by: None
Migration required: Yes, Truth templates become bilingual in-place

Rule:

Truth documents must be easy for humans to review and for AI to cite.

- Put rules before explanation.
- Use one stable Rule Block per important rule.
- Use stable IDs such as `RULE-DATA-001`.
- Make key rules verifiable.
- Keep boundaries clear: ADR explains why; SoT defines current behavior.

Rule Block format is defined by:

```text
.p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md
```

Important fields include Status, Applies to, Source, Supersedes, Superseded by, Migration required, Rule, Rationale, Validation, Downstream projections, and Stop-the-line if.

Validation:

- New or changed SoT rules use the Rule Block template.

Stop-the-line if:

- Active and implemented Truth is challenged without explicit lifecycle trail.

### RULE-GOV-005: English-first Single-file Bilingual Templates

Status: Superseded
Applies to: P2T2C-managed docs, prompts, templates, README files, and migration notes
Source: Template maintainers
Supersedes: `workflow: P2T2C Exception-Gated Workflow CN`, `language: zh-CN`
Superseded by: `RULE-GOV-006`
Migration required: Yes, template version `0.4.0`

Rule:

P2T2C-managed human and AI workflow documents use English-first single-file bilingual presentation:

- English is the default/global-facing language.
- Chinese appears alongside English in the same file for human and AI instructions.
- Stable workflow tokens, status values, file paths, command names, and CLI flags remain unchanged.
- Shell script runtime output remains English-only unless a future accepted CP changes that rule.
- Do not create parallel language-specific files such as `README.zh-CN.md` for the managed template.

Validation:

- `make check`
- `shasum -a 256 -c .p2t2c/CHECKSUMS.sha256`
- Manual scan of representative docs/templates confirms English appears first and Chinese is present.

Downstream projections:

- `P2T2C_README.md`, `P2T2C_AGENTS.md`, `.p2t2c/templates/project_config.example.yaml`, `.p2t2c/manifest.yaml`, `docs/sot/manifest.yaml`
- `.p2t2c/prompts/**`, `.p2t2c/templates/**`, `.p2t2c/templates/execution/**`, `docs/*/README.md`, `.p2t2c/migrations/**`

Stop-the-line if:

- A managed document removes Chinese equivalents for human/AI instructions.
- A change localizes script runtime output without an accepted CP.

### RULE-GOV-006: Dual Monolingual Release Roots

Status: Active
Applies to: P2T2C-managed docs, prompts, templates, README files, migration notes, and release packaging
Source: Maintainer decision on 2026-05-19
Supersedes: `RULE-GOV-005`
Superseded by: None
Migration required: Yes, template version `0.5.0`

Rule:

P2T2C is distributed as two self-contained language-specific release roots:

- `P2T2C_EN/` contains the English release.
- `P2T2C_CN/` contains the Chinese release.
- Each release root is independently installable, upgradeable, checkable, and carries its own `.p2t2c` metadata, checksums, lock file, internal prompts, templates, scripts, and Truth.
- Managed human and AI workflow documents, prompts, templates, README files, and migration notes must be monolingual inside each release root.
- Stable workflow tokens, status values, file paths, command names, CLI flags, and shell script runtime output remain English.
- The repository root is only a selector and aggregate check surface. It is not a P2T2C release root.

Rationale:

Single-file bilingual documents increase repeated context for AI readers. Dual monolingual release roots preserve language support while reducing per-task reading overhead.

Validation:

- `make check` at repository root runs checks for both release roots.
- `make check` passes inside `P2T2C_EN/` and `P2T2C_CN/`.
- `shasum -a 256 -c .p2t2c/CHECKSUMS.sha256` passes inside both release roots.
- Install and upgrade smoke tests pass for both release roots.
- Representative managed docs scan confirms same-file bilingual pairings are absent.

Downstream projections:

- Root selector: `README.md`, `AGENTS.md`, `Makefile`
- English release root: `P2T2C_EN/**`
- Chinese release root: `P2T2C_CN/**`

Stop-the-line if:

- A managed release-root document reintroduces same-file bilingual human/AI instructions.
- A release root cannot install, upgrade, or pass checks independently.
- A change localizes script runtime output without an accepted CP.

### RULE-GOV-007: Minimal Project-Root Surface

Status: Active
Applies to: P2T2C release packaging, install, upgrade, and managed path layout
Source: Maintainer decision on 2026-05-20
Supersedes: previous exposed internal asset layout
Superseded by: None
Migration required: Yes, template version `0.6.0`

Rule:

After P2T2C is installed into a project, only the user-facing P2T2C work surfaces are visible at the project root:

- `docs/`
- `specs/`

P2T2C internal runtime assets must live under `.p2t2c/`:

- `.p2t2c/prompts/**`
- `.p2t2c/templates/**`
- `.p2t2c/templates/execution/**`
- `.p2t2c/bin/**`
- `.p2t2c/migrations/**`

User-copyable entry templates may stay beside their target documents, such as `docs/change_proposals/CP_TEMPLATE.md`. Any new visible P2T2C root directory requires an accepted CP or ADR first.

Validation:

- `make check`
- Install smoke tests must not create root-level `prompts/`, `templates/`, `scripts/`, `sdd/`, or `migrations/`.
- Upgrade smoke tests must remove old root-level internal assets when the lock hash matches.

Downstream projections:

- `.p2t2c/ownership.yaml`
- `.p2t2c/manifest.yaml`
- `.p2t2c/bin/**`
- `.p2t2c/migrations/0.5.0-to-0.6.0.md`
- Human and AI entry documents

Stop-the-line if:

- A P2T2C change reintroduces a root-level internal asset directory.
- Upgrade would delete locally modified old internal assets.
- A visible P2T2C root directory is added without an accepted CP or ADR.

### RULE-GOV-008: P2T2C Root Entry File Names

Status: Active
Applies to: P2T2C release packaging, install, upgrade, and root-file projection
Source: Maintainer decision on 2026-05-20
Supersedes: root-level `README.md` and `AGENTS.md` as P2T2C installed entries
Superseded by: None
Migration required: Yes, template version `0.7.0`

Rule:

After P2T2C is installed into a project, exactly two P2T2C-specific root entry files may be projected:

- `P2T2C_README.md` is the primary human entry for understanding the P2T2C workflow.
- `P2T2C_AGENTS.md` is the P2T2C AI operational entry.

New installs must not create root-level `README.md`, `AGENTS.md`, `Makefile`, `CHECKSUMS.sha256`, `P2T2C_TEMPLATE_VERSION`, `P2T2C_LICENSE.md`, or `project_config.example.yaml`. Upgrade scripts may remove or migrate these old root files only when the lock hash proves they were not locally modified.

If an AI tool only auto-loads root-level `AGENTS.md`, users should manually reference `P2T2C_AGENTS.md` from their project-owned `AGENTS.md`.

Validation:

- `make check`
- New install smoke tests do not create old root files.
- `0.6.0 -> 0.7.0` upgrade smoke tests migrate unchanged old entry files.
- Upgrades must stop after local modifications to old `README.md`, `AGENTS.md`, or `Makefile`.

Downstream projections:

- `P2T2C_README.md`
- `P2T2C_AGENTS.md`
- `.p2t2c/CHECKSUMS.sha256`
- `.p2t2c/VERSION`
- `.p2t2c/P2T2C_LICENSE.md`
- `.p2t2c/templates/project_config.example.yaml`
- `.p2t2c/migrations/0.6.0-to-0.7.0.md`

Stop-the-line if:

- New install projects any old root file.
- Upgrade deletes or overwrites a locally modified old root entry or project Makefile.
- A managed document still treats `README.md` or `AGENTS.md` as the P2T2C installed target entry.

---

## 6. Execution Pack Rules

Execution Pack consists of:

```text
spec.md -> plan.md -> tasks.md
```

Rules:

- Coding requires all three documents unless the accepted process explicitly defines a smaller spec-lite path.
- `spec.md` states what the feature does and cites Truth references.
- `plan.md` states strategy, sequencing, and risks without writing full code.
- `tasks.md` breaks work into independently verifiable tasks.
- AI executes one task at a time.
- Each task must have an acceptance command or executable acceptance step.
- Actual results must be filled before marking a task done.
- Failed acceptance must not be marked complete.

---

## 7. Drift and Closure

Closure Report uses exactly three decisions:

| Decision | Meaning|
|---|---|
| `CLOSE` | Code, execution docs, and Truth are aligned.|
| `BACKFILL_EXECUTION_DOCS` | Code differs from spec|
| `HUMAN_TRUTH_DECISION_REQUIRED` | Code changed, extended, or violated SoT|

Drift labels:

| Label | Meaning | Handling |
|---|---|---|
| No Drift | Code, execution docs, and Truth align | `CLOSE` |
| Execution Doc Drift | Code differs from spec / plan / tasks, but Truth is unchanged | Backfill execution docs |
| Truth Drift | Code changes, extends, or violates SoT / ADR | Gate B |

Gate B options:

1. Fix code to match Truth.
2. Accept code and update Truth.
3. Create or update CP / ADR before deciding.

Acceptance failure is not Closure. Stop and report evidence.

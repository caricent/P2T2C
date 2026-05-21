# Spec {NNN}: {Feature Name}

Status: Draft | Approved | Implemented
Last updated: {YYYY-MM-DD}
Source SP: `{docs/submit_proposals/SP-...}`
Related ADR: `{docs/adr/ADR-... | None}`

---

## 0. Truth References

This spec only projects the Truth listed below. It does not add business rules.

| Truth file | Rule IDs / Sections |
|---|---|
| `{docs/sot/...}` | `{RULE-...}` |

Stop-the-line if:

- Implementation requires rules outside Truth references.
- Spec conflicts with SoT.
- Acceptance criteria require behavior not defined by SoT.

---

## 1. Background and Goal

### User Story

As a {role}, I want to {behavior}, so that {value}.

### Trigger

{Why do this now?}

### Non-goals

- {What this spec will not do.}

---

## 2. Functional Description

{Describe behavior grouped by capability.}

---

## 3. Parameters

| Parameter | Allowed values | Default | Description | Truth source |
|---|---|---|---|---|
| {name} | {values} | {default} | {desc} | {RULE-ID} |

---

## 4. Acceptance Criteria (EARS)

Each statement ends with the Truth rule identifier(s) it verifies (RULE-GOV-011). Every tagged identifier must also appear in section 0 Truth References.

- When {trigger}, the system shall {expected behavior}. [RULE-...]
- While {state}, the system shall {continuous behavior}. [RULE-...]
- The system shall not {forbidden behavior}. [RULE-...]

---

## 5. Domain Design

Reference or fill in based on project type:

- backend
- frontend
- mobile
- ai
- data

---

## 6. Truth Drift Watchlist

Stop during implementation if any of the following appears:

- {Boundary that may cause Truth Drift}

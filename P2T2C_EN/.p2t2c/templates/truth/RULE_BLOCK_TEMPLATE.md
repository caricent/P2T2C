### RULE-{AREA}-{NNN}: {Rule title}

Status: Draft | Active | Superseded | Deprecated
Applies to: {module / layer / workflow}
Source: {CP / ADR / human decision}
Supersedes: {RULE-ID or None}
Superseded by: {RULE-ID or None}
Migration required: Yes / No

Rule:

{One clear, executable, verifiable rule.}

Rationale:

{Why this rule exists.}

Validation:

- {automated test / manual acceptance / governance check / code review checklist}

Downstream projections:

- Spec: {which specs should cite this}
- Tests: {which tests should cover this}
- Code: {which modules should implement this}

Code anchor (RULE-GOV-010):

- Implementing code carries a pointer-only comment such as `Implements: RULE-{AREA}-{NNN}`.
- The anchor records the pointer only; the rule text stays in this SoT, never in the code comment.

Stop-the-line if:

- {when AI must pause for human confirmation}

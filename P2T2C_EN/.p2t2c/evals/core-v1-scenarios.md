# Core v1 Scenarios

| ID | Scenario | Expected |
|---|---|---|
| C-R0 | Read-only exploration | Create no artifact |
| C-R1 | Clear R1 | Generate approved SP, ready design, and tasks without another confirmation |
| C-R2P | Unresolved R2 | Decision pending; Apply and Archive are forbidden |
| C-R2A | Clear R2 | Update SOT and bind its digest before Apply |
| C-V | Verify not run | Record not_run honestly and allow Archive |
| C-B | Known failure | Any failed/critical/blocker/pending state blocks Archive |
| C-A | Normal Archive | Update only tasks status; execute no project command and create no evidence |
| C-M | Document migration | Dry-run writes nothing; apply/rollback is byte-exact |

Real Agent A/B separately measures non-business attention, first business edit, and end-to-end cycle. Deterministic fixtures do not replace the real evaluation.

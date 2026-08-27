# Superpowers Method Attribution

The native method layer in P2T2C 0.13.0 used [obra/superpowers](https://github.com/obra/superpowers) `v6.1.1` as its upstream reference baseline, reviewed on 2026-07-10. As of 2026-08-26, the latest reviewed formal release is [`v6.3.0`](https://github.com/obra/superpowers/releases/tag/v6.3.0); v0.14 evaluated the increments in [`v6.2.0`](https://github.com/obra/superpowers/releases/tag/v6.2.0) and v6.3.0.

## Practices Adapted

Method inspiration from v6.2:

- Plan/work-isolated temporary ledgers, with durable conclusions returning to Git and closure artifacts.
- Restore the original implementer for two repair rounds and scoped re-review only the finding and fix diff.
- Use falsifiable tests, independent expected values, and applicable mutation checks for actual behavior rather than text-only prompt/skill grep.
- Compress repeated method explanations and put hard constraints at behavior trigger points.

Method inspiration from v6.3:

- `spike / bounded / architectural` tiers, scaling artifact ceremony to work intensity.
- Batch homogeneous microtasks into a dispatch/review while still checking every brief item.
- Only a controller may spawn Agents; implementers/reviewers cannot recursively fan out.
- File-based brief/diff/evidence handoff, bounded event-driven waiting, and explicit model/reasoning tiers.
- Reviewers may read same-tree machine evidence; do not force-delete a worktree with untracked/uncommitted content.

These are method translations, not copied runtime. Efficiency and eval numbers in upstream releases/PRs are project self-reports and are not treated as P2T2C effectiveness evidence. `.p2t2c/evals/adaptive-v2-scenarios.md` defines an independent A/B scenario set; report results only after a real run.

v0.14 therefore trials adaptive-v2 in advisory mode only. It does not promote required without real A/B evidence plus a separate human decision. Receipt `local_consistency` is non-adversarial local consistency, not upstream or remote security attestation.

Truth-Patch digest, mandatory path mapping, ownership batch IDs, quiet/configured runner, advisory completeness/warnings, and atomic close are P2T2C controls and are not attributed to upstream Superpowers.

## P2T2C Boundaries Retained

- No uniform human approval for every task; Gate A applies only to undecided R2 semantics.
- Spec, plan, CPK, and run ledger cannot override SoT.
- No five repair rounds, parked nonzero findings, mandatory worktree per task, or one Agent per Task.
- The controller may resolve reversible non-semantic execution conflicts with recorded rationale; business, architecture, security, permission, data, dangerous, or external-side-effect boundaries still stop.
- A reviewer may avoid mechanically rerunning a suite on the same tree, but closure still requires fresh verification bound to the final tree.

P2T2C does not require, bundle, or execute the Superpowers plugin. The upstream project is released under the MIT License. This file provides method attribution and traceability without adding a runtime dependency.

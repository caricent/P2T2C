---
name: p2t2c-design-refinement
description: Refine a material product or technical ambiguity during P2T2C intent admission without creating competing Truth.
---

# Design Refinement

Use this method only when an ambiguity could change the implementation outcome. It refines intent; it does not define business rules.

1. Read the P2T2C entry, project configuration, relevant Truth, ADRs, and implementation evidence.
2. State the goal, non-goals, acceptance behaviors, and the precise unresolved decision.
3. Present viable options with a recommendation and their effect on Truth, risk, and verification.
4. Record the human decision in the current instruction, optional SP, or R2 CPK. If it changes current behavior, route it through Gate A and the Truth Patch.
5. Resume risk routing only when the intent is conflict-free.

Never save a separate design artifact merely to use this method. An SP remains optional, and no method artifact can become the sole source of a business rule.

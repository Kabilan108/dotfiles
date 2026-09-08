# Empirical review

Use this method when a consequential behavioral claim needs evidence: concurrency, retention, authorization, untrusted input, cache identity, or lifecycle behavior. Scope the review to the named change and its accepted design constraints.

Derive concrete invariants from the code or proposal. For each material suspicion, identify the input, sequence, or interleaving that would violate one. Run an isolated probe when feasible, recording the commit, environment, trigger and observed result. Keep temporary experiments separate from permanent tests; retain useful evidence.

Report outcomes as reproduced, disproved by a sufficient check, or unresolved. A green suite disproves a predicted test failure only if the relevant test, inputs, environment and commit match. A failed attempt to reproduce a race does not disprove an interleaving it never exercised. State access or runtime limits rather than inventing certainty.

A finding needs the affected location, failure scenario, impact, and evidence. Confirmation does not automatically expand the change: the lead adjudicates relevance and handles unrelated work separately. Re-review the affected behavior after fixes; add another reviewer only when requested or when the authorized review calls for that perspective.

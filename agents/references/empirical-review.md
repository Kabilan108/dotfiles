# Empirical review

Use this method when a consequential behavioral claim needs evidence: concurrency, retention, authorization, untrusted input, cache identity, or lifecycle behavior. Scope the review to the named change and its accepted design constraints.

Derive concrete invariants from the code or proposal. For each material suspicion, identify the input, sequence, or interleaving that would violate one. Run an isolated probe when feasible, recording the commit, environment, trigger and observed result. Keep temporary experiments separate from permanent tests; retain useful evidence.

Report outcomes as reproduced, disproved by a sufficient check, or unresolved. A green suite disproves a predicted test failure only if the relevant test, inputs, environment and commit match. A failed attempt to reproduce a race does not disprove an interleaving it never exercised. State access or runtime limits rather than inventing certainty.

A finding needs the affected location, failure scenario, impact, and evidence. Confirmation does not automatically expand the change: the lead adjudicates relevance and handles unrelated work separately. Re-review the affected behavior after fixes; add another reviewer only when requested or when the authorized review calls for that perspective.

## Data claims

Use this when numbers drive a ship, choose or keep decision: a benchmark, audit, comparison or analysis. An independent reviewer (a subagent that did not produce the numbers) works from the raw data and the commands that produced it, never from the charts or the author's summary.

- Recompute each headline number from the raw data.
- Check that every comparison is like for like: one metric definition, phase (peak or steady state, compile or first visible update), unit, environment, commit and sample. Flag each mixed comparison.
- Check that each chart shows the numbers it claims: axis scale and baseline, log decade spacing, the aggregate used (mean or median), and what error bars mean.
- Check that the sample and its spread support the strength of the claim. One run supports "observed once", not "faster".
- Check that each caption's claim follows from the data shown.

Report each claim as reproduced, corrected (old value, new value) or unsupported, with the commands run. The author fixes or withdraws each corrected or unsupported claim before handover, and the result states who checked and what was recomputed.

# Reports

A report states findings the user acts on: a benchmark, audit, review, comparison or analysis. The user has to trust every number on the page, so each chart and finding carries its own evidence.

## Charts

Each chart is a `<figure data-chart>` whose caption is one claim that can be true or false and that the chart shows: "The new worker sends 95% of messages within 2 s of their scheduled time."

A reader can tell from the chart alone what exactly is measured (including the phase: peak, steady state, first visible update), in what unit, over how many runs, how it was produced, and where the numbers live. Put each answer where it reads naturally: the metric and unit in the axis labels, the sample in the legend or caption, and the command, environment, commit and data link in one short source line under the chart.

- Compare like with like: one metric definition, one phase, one unit, one environment per chart. A peak beside a steady-state reading, or compile time beside visible-update time, goes in separate charts.
- Bars start at zero. A log axis says "log scale" in its label, with even decade spacing. Small multiples share one scale.
- With more than one run, show the spread (median with range or IQR) and say which statistic each mark is.
- Define every abbreviation and derived metric on first use (SD, p95, MAPE), with its formula when it is derived.
- The raw numbers are on the page in a collapsible table, or attached as a data file.
- A superseded result stays visible, marked as superseded, with what replaced it and why.

When the `dataviz` skill is available, use it for palette and mark design. This file sets what the chart must state; dataviz sets how it looks.

## Findings

A finding in a review or audit has its location (`path:line` at a commit), the failure scenario, the impact, and the evidence (a command and its output, a reproduction, or an excerpt). Order findings by severity. State what the review covered and what it did not.

## Limits and review status

- Say what the data does not show: untested environments, small samples, correlations without a mechanism.
- When the report's numbers drive a decision (ship, choose, keep), they go through an independent recompute before handover; see "Data claims" in `~/dotfiles/agents/references/empirical-review.md`. Show the result near the top: who checked, what was recomputed, and what changed.
